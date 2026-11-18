import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../domain/formats.dart';
import '../../domain/ladders.dart';
import '../../domain/models/claim.dart';

class ClaimRepository extends ChangeNotifier {
  ClaimRepository(this._db);

  final Database _db;
  List<Claim> _claims = const [];
  Future<void> _pending = Future.value();

  List<Claim> get claims => _claims;
  Claim? byId(String id) => _claims.where((claim) => claim.id == id).firstOrNull;
  Claim? openFor(String itemId) =>
      _claims.where((claim) => claim.itemId == itemId && claim.isOpen).firstOrNull;
  bool hasOpenClaim(String itemId) => openFor(itemId) != null;
  int needsAction(DateTime today) => _claims
      .where((claim) => claim.status(today) == ClaimStatus.escalate)
      .length;

  Future<void> load() async {
    final (rows, eventsByClaim) = await _db.transaction((txn) async {
      final rows = await txn.query('claims');
      final eventRows = await txn.query(
        'claim_events',
        orderBy: 'on_date DESC, created_at DESC, rowid DESC',
      );
      final events = <String, List<ClaimEvent>>{};
      for (final row in eventRows) {
        events.putIfAbsent(row['claim_id']! as String, () => []).add(
          ClaimEvent(
            id: row['id']! as String,
            on: parseIsoDate(row['on_date'])!,
            kind: ClaimEventKind.values.asNameMap()[row['kind']] ??
                ClaimEventKind.note,
            text: row['text']! as String,
          ),
        );
      }
      return (rows, events);
    });
    final claims = rows.map((row) {
      final id = row['id']! as String;
      final type = ClaimType.values.asNameMap()[row['type']] ?? ClaimType.repair;
      return Claim(
        id: id,
        itemId: row['item_id'] as String?,
        type: type,
        want: ClaimWant.values.asNameMap()[row['want']] ?? ClaimWant.repair,
        itemLabel: row['item_label']! as String,
        problem: row['problem']! as String,
        reference: row['reference']! as String,
        openedOn: parseIsoDate(row['opened_on'])!,
        noticedOn: parseIsoDate(row['noticed_on']),
        step: (row['step']! as int).clamp(0, ladderFor(type).length - 1),
        stepSince: parseIsoDate(row['step_since'])!,
        lastHeardOn: parseIsoDate(row['last_heard_on']),
        settledOn: parseIsoDate(row['settled_on']),
        nudgeDays: row['nudge_days']! as int,
        events: List.unmodifiable(eventsByClaim[id] ?? const <ClaimEvent>[]),
      );
    }).toList()..sort(_compare);
    _claims = List.unmodifiable(claims);
    notifyListeners();
  }

  Future<Claim> start({
    required String itemId,
    required String itemLabel,
    required ClaimType type,
    required ClaimWant want,
    required String problem,
    String reference = '',
    DateTime? noticedOn,
    required DateTime today,
  }) => _write((txn) async {
    if (problem.trim().isEmpty) {
      throw const FormatException('Add a short description of what happened.');
    }
    _checkNoOpenClaim(itemId);
    final id = const Uuid().v4();
    await txn.insert('claims', {
      'id': id,
      'item_id': itemId,
      'item_label': itemLabel,
      'type': type.name,
      'want': want.name,
      'problem': problem.trim(),
      'reference': reference.trim(),
      'opened_on': isoDate(today),
      'noticed_on': noticedOn == null ? null : isoDate(noticedOn),
      'step_since': isoDate(today),
      'nudge_days': ladderFor(type).first.waitDays,
    });
    await _event(txn, id, today, ClaimEventKind.opened, 'Claim opened');
    return id;
  }).then((id) => byId(id)!);

  Future<void> logSent(String id, DateTime today) => _write((txn) async {
    final claim = _getOpen(id);
    final recipient = ladderFor(claim.type)[claim.step].recipient;
    await _event(
      txn, id, today, ClaimEventKind.sent, 'Sent the message to $recipient',
    );
  });

  Future<void> logReply(String id, DateTime today, {String note = ''}) =>
      _write((txn) async {
        _getOpen(id);
        await _update(txn, id, {'last_heard_on': isoDate(today)});
        await _event(txn, id, today, ClaimEventKind.reply, _note(note, 'Reply received'));
      });

  Future<void> advance(String id, DateTime today) => _write((txn) async {
    final claim = _getOpen(id);
    final ladder = ladderFor(claim.type);
    final step = claim.step + 1;
    if (step >= ladder.length) return;
    await _update(txn, id, {
      'step': step,
      'step_since': isoDate(today),
      'nudge_days': ladder[step].waitDays,
    });
    await _event(txn, id, today, ClaimEventKind.step, stepTitle(claim.type, step));
  });

  Future<void> addNote(String id, DateTime today, String text) =>
      _write((txn) async {
        _get(id);
        if (text.trim().isEmpty) throw const FormatException('Write a short note.');
        await _event(txn, id, today, ClaimEventKind.note, text.trim());
      });

  Future<void> settle(String id, DateTime today, {String note = ''}) =>
      _write((txn) async {
        if (!_get(id).isOpen) return;
        await _update(txn, id, {'settled_on': isoDate(today)});
        await _event(txn, id, today, ClaimEventKind.settled, _note(note, 'Claim settled'));
      });

  Future<void> reopen(String id, DateTime today) => _write((txn) async {
    final claim = _get(id);
    if (claim.isOpen) return;
    final itemId = claim.itemId;
    if (itemId != null) _checkNoOpenClaim(itemId);
    await _update(txn, id, {'settled_on': null, 'step_since': isoDate(today)});
    await _event(txn, id, today, ClaimEventKind.reopened, 'Claim reopened');
  });

  Future<void> delete(String id) => _write((txn) async {
    await txn.delete('claims', where: 'id = ?', whereArgs: [id]);
  });

  Future<void> eraseAll() => _write((txn) async {
    await txn.delete('claims');
  });

  Future<T> _write<T>(Future<T> Function(Transaction txn) operation) {
    final result = _pending.then((_) async {
      final value = await _db.transaction(operation);
      await load();
      return value;
    });
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Claim _get(String id) =>
      byId(id) ?? (throw const FormatException('This claim is no longer here.'));

  Claim _getOpen(String id) {
    final claim = _get(id);
    if (!claim.isOpen) throw const FormatException('Reopen this claim to continue.');
    return claim;
  }

  void _checkNoOpenClaim(String itemId) {
    if (hasOpenClaim(itemId)) {
      throw const FormatException('There’s already an open claim for this item.');
    }
  }

  Future<void> _update(Transaction txn, String id, Map<String, Object?> fields) async {
    await txn.update('claims', fields, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> _event(
    Transaction txn, String id, DateTime date, ClaimEventKind kind, String text,
  ) async {
    await txn.insert('claim_events', {
      'id': const Uuid().v4(),
      'claim_id': id,
      'on_date': isoDate(date),
      'kind': kind.name,
      'text': text,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  static String _note(String note, String fallback) =>
      note.trim().isEmpty ? fallback : note.trim();

  static int _compare(Claim a, Claim b) {
    if (a.isOpen != b.isOpen) return a.isOpen ? -1 : 1;
    final time = a.isOpen
        ? a.waitingSince.compareTo(b.waitingSince)
        : b.settledOn!.compareTo(a.settledOn!);
    return time == 0 ? a.id.compareTo(b.id) : time;
  }
}
