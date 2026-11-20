import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../domain/formats.dart';
import '../../domain/item_status.dart';
import '../../domain/models/item.dart';
import '../services/file_store.dart';

/// Thrown when adding (or restoring) an item would go past the Base plan cap.
class LimitReachedException implements Exception {
  const LimitReachedException();

  String get message =>
      '$baseItemLimit of $baseItemLimit items on Base. Nothing is deleted. '
      'Archive an old item to add a new one.';

  @override
  String toString() => message;
}

/// The single source of truth for everything in the drawer.
class ItemRepository extends ChangeNotifier {
  ItemRepository(this._db, this._files, {bool Function()? onBasePlan})
    : _onBasePlan = onBasePlan;

  final Database _db;
  final FileStore _files;
  final bool Function()? _onBasePlan;
  List<Item> _items = const [];
  Future<void> _pending = Future.value();
  bool _closed = false;

  /// Every item, newest first, archived ones included.
  List<Item> get items => _items;

  List<Item> get active =>
      _items.where((item) => !item.isArchived).toList(growable: false);

  List<Item> get archived =>
      _items.where((item) => item.isArchived).toList(growable: false);

  int get activeCount => _items.where((item) => !item.isArchived).length;

  bool get onBasePlan => _onBasePlan?.call() ?? true;
  bool get atLimit => onBasePlan && activeCount >= baseItemLimit;

  Item? byId(String id) => _items.where((item) => item.id == id).firstOrNull;

  Future<void> load() async {
    _items = await _readAll();
    notifyListeners();
  }

  Future<Item> create(ItemDraft draft, {List<PendingFile> files = const []}) =>
      _enqueue(() async {
        if (atLimit) throw const LimitReachedException();
        _validate(draft);
        final id = const Uuid().v4();
        final copied = await _importAll(id, files);
        final now = DateTime.now().millisecondsSinceEpoch;
        try {
          await _db.transaction((txn) async {
            await txn.insert('items', {
              'id': id,
              ..._encode(draft),
              'created_at': now,
              'updated_at': now,
            });
            await _insertAttachments(txn, id, copied, firstPosition: 0);
          });
        } catch (_) {
          await _removeFiles(copied);
          rethrow;
        }
        await _refresh();
        return byId(id)!;
      });

  Future<Item> update(
    String id,
    ItemDraft draft, {
    List<PendingFile> addFiles = const [],
    Set<String> removeAttachmentIds = const {},
    bool prependOriginal = false,
  }) => _enqueue(() async {
    final existing = byId(id);
    if (existing == null) {
      throw StateError('This item is no longer in the drawer.');
    }
    _validate(draft);
    final copied = await _importAll(id, addFiles);
    final removed = existing.attachments
        .where((a) => removeAttachmentIds.contains(a.id))
        .toList();
    final kept = existing.attachments.length - removed.length;
    try {
      await _db.transaction((txn) async {
        final count = await txn.update(
          'items',
          {
            ..._encode(draft),
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
        if (count != 1) {
          throw StateError('This item is no longer in the drawer.');
        }
        for (final attachment in removed) {
          await txn.delete(
            'attachments',
            where: 'id = ? AND item_id = ?',
            whereArgs: [attachment.id, id],
          );
        }
        if (prependOriginal && copied.isNotEmpty) {
          await txn.rawUpdate(
            'UPDATE attachments SET position = position + ? WHERE item_id = ?',
            [copied.length, id],
          );
        }
        await _insertAttachments(
          txn,
          id,
          copied,
          firstPosition: prependOriginal ? 0 : kept,
        );
      });
    } catch (_) {
      await _removeFiles(copied);
      rethrow;
    }
    // Only remove originals once the database no longer points at them.
    await _removeFiles(removed);
    await _refresh();
    return byId(id)!;
  });

  Future<void> setArchived(String id, bool archived) => _enqueue(() async {
    final item = byId(id);
    if (item == null) throw StateError('This item is no longer in the drawer.');
    if (item.isArchived == archived) return;
    if (!archived && atLimit) throw const LimitReachedException();
    await _db.update(
      'items',
      {'archived_at': archived ? DateTime.now().millisecondsSinceEpoch : null},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _refresh();
  });

  /// Removes the item and its originals. Claims about it keep their own
  /// `item_label` and simply lose the link.
  Future<void> delete(String id) => _enqueue(() async {
    final item = byId(id);
    if (item == null) return;
    await _db.delete('items', where: 'id = ?', whereArgs: [id]);
    await _removeFiles(item.attachments);
    await _refresh();
  });

  Future<void> eraseAll() => _enqueue(() async {
    await _db.transaction((txn) async {
      await txn.delete('attachments');
      await txn.delete('items');
      final legacy = await txn.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'records_v1_backup'",
      );
      if (legacy.isNotEmpty) await txn.delete('records_v1_backup');
    });
    await _files.removeAll();
    await _refresh();
  });

  // ---------------------------------------------------------------------------

  Future<void> finishWrites() {
    _closed = true;
    return _pending;
  }

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    if (_closed) return Future.error(StateError('This drawer is closed.'));
    final result = _pending.then((_) => operation());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> _refresh() async {
    _items = await _readAll();
    notifyListeners();
  }

  void _validate(ItemDraft draft) {
    if (draft.name.trim().isEmpty) {
      throw const FormatException('Add a name so you can find it later.');
    }
  }

  Future<List<Attachment>> _importAll(
    String itemId,
    List<PendingFile> files,
  ) async {
    final copied = <Attachment>[];
    try {
      for (final file in files) {
        copied.add(await _files.import(itemId, file));
      }
    } catch (_) {
      await _removeFiles(copied);
      rethrow;
    }
    return copied;
  }

  Future<void> _removeFiles(List<Attachment> attachments) async {
    for (final attachment in attachments) {
      await _files.remove(attachment.path);
    }
  }

  Future<void> _insertAttachments(
    Transaction txn,
    String itemId,
    List<Attachment> attachments, {
    required int firstPosition,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < attachments.length; i++) {
      final a = attachments[i];
      await txn.insert('attachments', {
        'id': a.id,
        'item_id': itemId,
        'rel_path': _files.relative(a.path),
        'name': a.name,
        'bytes': a.bytes,
        'position': firstPosition + i,
        'created_at': now,
      });
    }
  }

  Map<String, Object?> _encode(ItemDraft d) => {
    'kind': d.kind.name,
    'name': d.name.trim(),
    'source': d.source.trim(),
    'subtype': d.subtype.trim(),
    'reference': d.reference.trim(),
    'serial_number': d.serialNumber.trim(),
    'notes': d.notes.trim(),
    'amount_minor': d.amountMinor,
    'currency': d.currency,
    'starts_on': d.startsOn == null ? null : isoDate(d.startsOn!),
    'return_until': d.returnUntil == null ? null : isoDate(d.returnUntil!),
    'cover_until': d.coverUntil == null ? null : isoDate(d.coverUntil!),
    'component_warranty_until':
        d.kind == ItemKind.bill && d.componentWarrantyUntil != null
        ? isoDate(d.componentWarrantyUntil!)
        : null,
    'component_warranty_name':
        d.kind == ItemKind.bill && d.componentWarrantyUntil != null
        ? d.componentWarrantyName.trim()
        : '',
    'remind': d.remind ? 1 : 0,
    'reminder_at': d.reminderAt?.millisecondsSinceEpoch,
    'coverage_renews': switch (d.coverageRenews) {
      true => 1,
      false => 0,
      null => null,
    },
  };

  Future<List<Item>> _readAll() async {
    final rows = await _db.query('items', orderBy: 'created_at DESC, id DESC');
    final attachmentRows = await _db.query(
      'attachments',
      orderBy: 'position ASC, created_at ASC',
    );
    final byItem = <String, List<Attachment>>{};
    for (final row in attachmentRows) {
      byItem
          .putIfAbsent(row['item_id']! as String, () => [])
          .add(
            Attachment(
              id: row['id']! as String,
              path: _files.absolute(row['rel_path']! as String),
              name: row['name']! as String,
              bytes: row['bytes'] as int? ?? 0,
            ),
          );
    }
    return rows
        .map((row) {
          final id = row['id']! as String;
          final archivedAt = row['archived_at'] as int?;
          return Item(
            id: id,
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              row['created_at']! as int,
            ),
            archivedAt: archivedAt == null
                ? null
                : DateTime.fromMillisecondsSinceEpoch(archivedAt),
            attachments: List.unmodifiable(byItem[id] ?? const <Attachment>[]),
            draft: ItemDraft(
              kind:
                  ItemKind.values.asNameMap()[row['kind']] ??
                  ItemKind.agreement,
              name: row['name']! as String,
              source: row['source'] as String? ?? '',
              subtype: row['subtype'] as String? ?? '',
              reference: row['reference'] as String? ?? '',
              serialNumber: row['serial_number'] as String? ?? '',
              notes: row['notes'] as String? ?? '',
              amountMinor: row['amount_minor'] as int?,
              currency: row['currency'] as String? ?? 'INR',
              startsOn: parseIsoDate(row['starts_on']),
              returnUntil: parseIsoDate(row['return_until']),
              coverUntil: parseIsoDate(row['cover_until']),
              componentWarrantyUntil: parseIsoDate(
                row['component_warranty_until'],
              ),
              componentWarrantyName:
                  row['component_warranty_name'] as String? ?? '',
              remind: (row['remind'] as int? ?? 1) == 1,
              reminderAt: row['reminder_at'] is int
                  ? DateTime.fromMillisecondsSinceEpoch(
                      row['reminder_at']! as int,
                    )
                  : null,
              coverageRenews: switch (row['coverage_renews']) {
                1 => true,
                0 => false,
                _ => null,
              },
            ),
          );
        })
        .toList(growable: false);
  }
}
