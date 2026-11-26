import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'file_store.dart';
import 'legacy_claims.dart';

/// Claims the old unassigned drawer explicitly and preserves the source as a
/// recovery copy. The destination marker commits with all imported records.
class LegacyDrawerImport {
  const LegacyDrawerImport(this._source, this._root);

  static const _ownerKey = 'legacy_drawer_owner';
  static const _importedKey = 'legacy_drawer_imported';
  static const _tables = ['items', 'attachments', ...LegacyClaimTables.all];
  static const _settings = [
    'reminders_on',
    'lead_days',
    'ticket_dismissed_key',
    'reminders_offered',
  ];
  final Database _source;
  final Directory _root;

  static Future<bool> isClaimed(Database db) async =>
      await _preference(db, _ownerKey) != null;

  Future<bool> canImport(String owner) async {
    final claimed = await _preference(_source, _ownerKey);
    if (claimed != null && claimed != owner) return false;
    final rows = await _source.rawQuery('''
      SELECT 1 FROM items
      UNION SELECT 1 FROM ${LegacyClaimTables.claims}
      LIMIT 1
    ''');
    return rows.isNotEmpty;
  }

  Future<bool> isImported(Database destination) async =>
      await _preference(destination, _importedKey) == '1';

  Future<void> copyTo(
    String owner,
    Database destination,
    FileStore originals,
  ) async {
    if (await isImported(destination)) return;
    await _source.transaction((txn) async {
      final claimed = await _preference(txn, _ownerKey);
      if (claimed != null && claimed != owner) {
        throw const FormatException(
          'This drawer already belongs to an account.',
        );
      }
      if (claimed == null) {
        await txn.insert('preferences', {'key': _ownerKey, 'value': owner});
      }
    });

    final copied = <File>[];
    try {
      final snapshot = await _source.transaction(
        (txn) async => {
          for (final table in [..._tables, 'preferences'])
            table: await txn.query(table),
        },
      );
      for (final table in ['attachments', LegacyClaimTables.eventPhotos]) {
        snapshot[table] = [
          for (final row in snapshot[table]!)
            await _copy(
              row,
              originals,
              copied,
              claimPhoto: table == LegacyClaimTables.eventPhotos,
            ),
        ];
      }
      await destination.transaction((txn) async {
        final batch = txn.batch();
        for (final table in _tables) {
          for (final row in snapshot[table]!) {
            batch.insert(table, row);
          }
        }
        for (final row in snapshot['preferences']!) {
          if (_settings.contains(row['key'])) {
            batch.insert(
              'preferences',
              row,
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );
          }
        }
        batch.insert('preferences', {'key': _importedKey, 'value': '1'});
        await batch.commit(noResult: true);
      });
    } catch (_) {
      for (final file in copied) {
        await originals.remove(file.path);
      }
      rethrow;
    }
  }

  Future<Map<String, Object?>> _copy(
    Map<String, Object?> row,
    FileStore originals,
    List<File> copied, {
    required bool claimPhoto,
  }) async {
    final relative = row['rel_path']! as String;
    final path = p.normalize(p.join(_root.path, relative));
    if (p.isAbsolute(relative) || !p.isWithin(_root.path, path)) {
      throw const FormatException(
        'An original in the older drawer has an invalid path.',
      );
    }
    final folder = claimPhoto ? 'claim-photos' : 'attachments';
    final name =
        '${const Uuid().v4()}-${const Uuid().v4()}${p.extension(path)}';
    final target = File(originals.absolute(p.join(folder, name)));
    await target.parent.create(recursive: true);
    copied.add(target);
    await File(path).copy(target.path);
    return {...row, 'rel_path': originals.relative(target.path)};
  }

  static Future<String?> _preference(DatabaseExecutor db, String key) async {
    final rows = await db.query(
      'preferences',
      where: 'key = ?',
      whereArgs: [key],
    );
    return rows.firstOrNull?['value'] as String?;
  }
}
