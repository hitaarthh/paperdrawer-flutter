import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'vault_record.dart';
import 'vault_repository.dart';

const maxAttachmentBytes = 20 * 1024 * 1024;
const attachmentExtensions = {
  '.pdf',
  '.jpg',
  '.jpeg',
  '.png',
  '.heic',
  '.heif',
  '.webp',
};

class SqliteVaultRepository implements VaultRepository {
  SqliteVaultRepository._(this._database, this._directory);

  final Database _database;
  final Directory _directory;

  static Future<SqliteVaultRepository> open(
    Directory directory, {
    DatabaseFactory? factory,
  }) async {
    await directory.create(recursive: true);
    final database = await (factory ?? databaseFactory).openDatabase(
      p.join(directory.path, 'vault.sqlite'),
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE records (
              id TEXT PRIMARY KEY,
              kind TEXT NOT NULL CHECK (kind IN ('receipt', 'policy', 'document')),
              title TEXT NOT NULL,
              source TEXT NOT NULL DEFAULT '',
              notes TEXT NOT NULL DEFAULT '',
              amount_cents INTEGER CHECK (amount_cents >= 0),
              recorded_on TEXT,
              deadline TEXT,
              attachment_key TEXT,
              attachment_name TEXT,
              created_at INTEGER NOT NULL,
              archived_at INTEGER
            )
          ''');
          await db.execute('''
            CREATE TABLE preferences (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL
            )
          ''');
        },
      ),
    );
    return SqliteVaultRepository._(database, directory);
  }

  @override
  Future<List<VaultRecord>> readAll() async {
    final rows = await _database.query(
      'records',
      orderBy: 'created_at DESC, id DESC',
    );
    return rows.map(_decode).toList(growable: false);
  }

  @override
  Future<void> save(
    VaultDraft draft, {
    String? id,
    VaultAttachment? import,
  }) async {
    if (draft.title.trim().isEmpty) {
      throw const FormatException('Enter a name for this item.');
    }

    final recordId = id ?? const Uuid().v4();
    final attachmentKey = import == null
        ? null
        : await _copyAttachment(recordId, import);
    final values = <String, Object?>{
      'kind': draft.kind.name,
      'title': draft.title.trim(),
      'source': draft.source.trim(),
      'notes': draft.notes.trim(),
      'amount_cents': draft.amountCents,
      'recorded_on': _encodeDate(draft.recordedOn),
      'deadline': _encodeDate(draft.deadline),
      if (import != null) ...{
        'attachment_key': attachmentKey,
        'attachment_name': import.name,
      },
    };

    try {
      if (id == null) {
        await _database.insert('records', {
          'id': recordId,
          'created_at': DateTime.now().millisecondsSinceEpoch,
          ...values,
        });
      } else {
        final updated = await _database.update(
          'records',
          values,
          where: 'id = ?',
          whereArgs: [recordId],
        );
        if (updated != 1) throw StateError('Record is unavailable.');
      }
    } catch (_) {
      if (attachmentKey != null) {
        await File(p.join(_directory.path, attachmentKey)).delete();
      }
      rethrow;
    }
  }

  Future<String> _copyAttachment(
    String recordId,
    VaultAttachment attachment,
  ) async {
    final source = File(attachment.path);
    final suffix = p.extension(attachment.name).toLowerCase();
    final size = await source.length();
    if (!attachmentExtensions.contains(suffix)) {
      throw const FormatException('Choose a photo or PDF.');
    }
    if (size == 0 || size > maxAttachmentBytes) {
      throw const FormatException('Choose a file between 1 byte and 20 MB.');
    }

    final key = p.join('attachments', '$recordId-${const Uuid().v4()}$suffix');
    final target = File(p.join(_directory.path, key));
    await target.parent.create(recursive: true);
    try {
      await source.copy(target.path);
    } catch (_) {
      if (await target.exists()) await target.delete();
      rethrow;
    }
    return key;
  }

  @override
  Future<void> setArchived(String id, bool archived) async {
    final updated = await _database.update(
      'records',
      {'archived_at': archived ? DateTime.now().millisecondsSinceEpoch : null},
      where: 'id = ?',
      whereArgs: [id],
    );
    if (updated != 1) throw StateError('Record is unavailable.');
  }

  @override
  Future<VaultAppearance> readTheme() async {
    final rows = await _database.query(
      'preferences',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['appearance'],
      limit: 1,
    );
    final value = rows.firstOrNull?['value'];
    return VaultAppearance.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => VaultAppearance.system,
    );
  }

  @override
  Future<void> setTheme(VaultAppearance theme) async {
    await _database.insert('preferences', {
      'key': 'appearance',
      'value': theme.name,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> close() => _database.close();

  VaultRecord _decode(Map<String, Object?> row) {
    final key = row['attachment_key'] as String?;
    final archivedAt = row['archived_at'] as int?;
    return VaultRecord(
      id: row['id']! as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at']! as int),
      archivedAt: archivedAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(archivedAt),
      draft: VaultDraft(
        kind: RecordKind.values.byName(row['kind']! as String),
        title: row['title']! as String,
        source: row['source']! as String,
        notes: row['notes']! as String,
        amountCents: row['amount_cents'] as int?,
        recordedOn: _decodeDate(row['recorded_on']),
        deadline: _decodeDate(row['deadline']),
      ),
      attachment: key == null
          ? null
          : VaultAttachment(
              path: p.join(_directory.path, key),
              name: row['attachment_name']! as String,
            ),
    );
  }
}

String? _encodeDate(DateTime? value) =>
    value == null ? null : civilDate(value).toIso8601String().split('T').first;

DateTime? _decodeDate(Object? value) =>
    value is String ? DateTime.tryParse('${value}T00:00:00Z') : null;
