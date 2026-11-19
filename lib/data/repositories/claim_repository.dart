import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../domain/formats.dart';
import '../../domain/ladders.dart';
import '../../domain/models/claim.dart';
import '../../domain/models/item.dart';
import '../../domain/models/ledger.dart';
import '../services/file_store.dart';

class ClaimRepository extends ChangeNotifier {
  ClaimRepository(this._db, this._files);

  final Database _db;
  final FileStore _files;
  List<Claim> _claims = const [];
  Future<void> _pending = Future.value();

  List<Claim> get claims => _claims;
  Claim? byId(String id) =>
      _claims.where((claim) => claim.id == id).firstOrNull;
  Claim? openFor(String itemId) => _claims
      .where((claim) => claim.itemId == itemId && claim.isOpen)
      .firstOrNull;
  bool hasOpenClaim(String itemId) => openFor(itemId) != null;
  int needsAction(DateTime today) => _claims
      .where((claim) => claim.status(today) == ClaimStatus.escalate)
      .length;

  Future<void> load() async {
    final (rows, eventsByClaim) = await _db.transaction((txn) async {
      final rows = await txn.query('claims');
      final eventRows = await txn.rawQuery('''
        SELECT event.*, photo.rel_path, photo.name AS photo_name, photo.bytes
        FROM claim_events AS event
        LEFT JOIN claim_event_photos AS photo ON photo.event_id = event.id
        ORDER BY event.on_date DESC, event.created_at DESC, event.rowid DESC
      ''');
      final events = <String, List<ClaimEvent>>{};
      for (final row in eventRows) {
        events
            .putIfAbsent(row['claim_id']! as String, () => [])
            .add(
              ClaimEvent(
                id: row['id']! as String,
                on: parseIsoDate(row['on_date'])!,
                kind:
                    ClaimEventKind.values.asNameMap()[row['kind']] ??
                    ClaimEventKind.note,
                text: row['text']! as String,
                reference: row['reference']! as String,
                photo: _photo(row),
              ),
            );
      }
      return (rows, events);
    });
    final claims = rows.map((row) {
      final id = row['id']! as String;
      final type =
          ClaimType.values.asNameMap()[row['type']] ?? ClaimType.repair;
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
        followUp: switch (row['follow_up_at']) {
          final int ms => DateTime.fromMillisecondsSinceEpoch(ms),
          _ => null,
        },
        events: List.unmodifiable(eventsByClaim[id] ?? const <ClaimEvent>[]),
      );
    }).toList()..sort(_compare);
    _claims = List.unmodifiable(claims);
    notifyListeners();
  }

  Attachment? _photo(Map<String, Object?> row) {
    final path = row['rel_path'] as String?;
    return path == null ? null : Attachment(
      id: row['id']! as String,
      path: _files.absolute(path),
      name: row['photo_name']! as String,
      bytes: row['bytes']! as int,
    );
  }

  Future<Claim> openLedger(Item item, DateTime today) => _write((txn) async {
    if (openFor(item.id) case final existing?) return existing.id;
    final type = item.kind == ItemKind.policy ? ClaimType.insurance : ClaimType.repair;
    final id = const Uuid().v4();
    await txn.insert('claims', {
      'id': id,
      'item_id': item.id,
      'item_label': item.name,
      'type': type.name,
      'want': (type == ClaimType.insurance ? ClaimWant.payout : ClaimWant.repair).name,
      'opened_on': isoDate(today),
      'step_since': isoDate(today),
      'nudge_days': 0,
    });
    await _event(txn, id, today, ClaimEventKind.opened, 'Claim opened');
    return id;
  }).then((id) => byId(id)!);

  Future<void> addEntry(String id, LedgerDraft entry, DateTime now) =>
      _enqueue(() async {
        _getOpen(id);
        entry.validate(now);
        final picked = entry.photo;
        final photo = picked == null ? null : await _files.import(id, picked, claimPhoto: true);
        try {
          await _db.transaction((txn) async {
            final eventId = await _event(
              txn, id, entry.date,
              ClaimEventKind.values.byName(entry.kind.name),
              entry.text, reference: entry.reference,
            );
            if (photo != null) {
              await txn.insert('claim_event_photos', {
                'event_id': eventId,
                'rel_path': _files.relative(photo.path),
                'name': photo.name,
                'bytes': photo.bytes,
              });
            }
            if (entry.followUp case final time?) {
              await _update(txn, id, {'follow_up_at': time.millisecondsSinceEpoch});
            }
          });
        } catch (_) {
          if (photo != null) await _files.remove(photo.path);
          rethrow;
        }
        await load();
      });

  Future<void> setFollowUp(String id, DateTime? followUp, DateTime now) =>
      _write((txn) async {
        _getOpen(id);
        validateFollowUp(followUp, now);
        await _update(txn, id, {'follow_up_at': followUp?.millisecondsSinceEpoch});
      });

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

  Future<void> logSent(String id, DateTime today, {int? step}) =>
      _write((txn) async {
        final claim = _getOpen(id);
        final target = step ?? claim.step;
        if (target != claim.step) {
          if (target != recommendedStepFor(claim, today)) {
            throw const FormatException(
              'The current step changed. Review your draft and try again.',
            );
          }
          await _advance(txn, claim, today);
        }
        final recipient = ladderFor(claim.type)[target].recipient;
        await _event(
          txn,
          id,
          today,
          ClaimEventKind.sent,
          'Sent the message to $recipient',
        );
      });

  Future<void> logReply(String id, DateTime today, {String note = ''}) =>
      _write((txn) async {
        _getOpen(id);
        await _update(txn, id, {'last_heard_on': isoDate(today)});
        await _event(
          txn,
          id,
          today,
          ClaimEventKind.reply,
          _note(note, 'Reply received'),
        );
      });

  Future<void> advance(String id, DateTime today) =>
      _write((txn) => _advance(txn, _getOpen(id), today));

  Future<void> _advance(Transaction txn, Claim claim, DateTime today) async {
    final ladder = ladderFor(claim.type);
    final step = claim.step + 1;
    if (step >= ladder.length) return;
    await _update(txn, claim.id, {
      'step': step,
      'step_since': isoDate(today),
      'nudge_days': ladder[step].waitDays,
    });
    await _event(
      txn,
      claim.id,
      today,
      ClaimEventKind.step,
      stepTitle(claim.type, step),
    );
  }

  Future<void> addNote(String id, DateTime today, String text) => _write((
    txn,
  ) async {
    _get(id);
    if (text.trim().isEmpty) throw const FormatException('Write a short note.');
    await _event(txn, id, today, ClaimEventKind.note, text.trim());
  });

  Future<void> settle(String id, DateTime today, {String note = ''}) =>
      _write((txn) async {
        if (!_get(id).isOpen) return;
        await _update(txn, id, {'settled_on': isoDate(today), 'follow_up_at': null});
        await _event(
          txn,
          id,
          today,
          ClaimEventKind.settled,
          _note(note, 'Claim settled'),
        );
      });

  Future<void> reopen(String id, DateTime today) => _write((txn) async {
    final claim = _get(id);
    if (claim.isOpen) return;
    final itemId = claim.itemId;
    if (itemId != null) _checkNoOpenClaim(itemId);
    await _update(txn, id, {'settled_on': null, 'step_since': isoDate(today)});
    await _event(txn, id, today, ClaimEventKind.reopened, 'Claim reopened');
  });

  Future<void> delete(String id) => _deleteClaims(id);

  Future<void> eraseAll() => _deleteClaims(null);

  Future<void> _deleteClaims(String? id) => _enqueue(() async {
    final photos = [
      for (final claim in claims)
        if (id == null || claim.id == id)
          for (final event in claim.events)
            if (event.photo case final photo?) photo,
    ];
    await _db.delete('claims', where: id == null ? null : 'id = ?', whereArgs: id == null ? null : [id]);
    for (final photo in photos) {
      await _files.remove(photo.path);
    }
    await load();
  });

  Future<T> _write<T>(Future<T> Function(Transaction txn) operation) =>
      _enqueue(() async {
        final value = await _db.transaction(operation);
        await load();
        return value;
      });

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final result = _pending.then((_) => operation());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Claim _get(String id) =>
      byId(id) ??
      (throw const FormatException('This claim is no longer here.'));

  Claim _getOpen(String id) {
    final claim = _get(id);
    if (!claim.isOpen) {
      throw const FormatException('Reopen this claim to continue.');
    }
    return claim;
  }

  void _checkNoOpenClaim(String itemId) {
    if (hasOpenClaim(itemId)) {
      throw const FormatException(
        'There’s already an open claim for this item.',
      );
    }
  }

  Future<void> _update(
    Transaction txn,
    String id,
    Map<String, Object?> fields,
  ) async {
    await txn.update('claims', fields, where: 'id = ?', whereArgs: [id]);
  }

  Future<String> _event(
    Transaction txn,
    String id,
    DateTime date,
    ClaimEventKind kind,
    String text, {
    String reference = '',
  }) async {
    final eventId = const Uuid().v4();
    await txn.insert('claim_events', {
      'id': eventId,
      'claim_id': id,
      'on_date': isoDate(date),
      'kind': kind.name,
      'text': text,
      'reference': reference,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    return eventId;
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
