import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

/// Opens the drawer's SQLite database and keeps its schema current.
///
/// Version history:
/// - v1: a single `records` table with one optional attachment per record.
/// - v2: items, attachments (many per item), claims, claim events.
/// - v3: optional bill serial numbers.
/// - v4: claim follow-ups, event references, and entry photos.
/// - v5: component warranty dates and names.
abstract final class AppDatabase {
  static const version = 5;

  static Future<Database> open(String path, {DatabaseFactory? factory}) =>
      (factory ?? databaseFactory).openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: version,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
          onCreate: (db, _) => db.transaction((txn) async {
            await _createV2(txn);
            await _addSerialNumber(txn);
            await _addLedger(txn);
            await _addComponentWarranty(txn);
          }),
          onUpgrade: (db, from, to) => db.transaction((txn) async {
            if (from < 2) await _migrateV1ToV2(txn);
            if (from < 3) await _addSerialNumber(txn);
            if (from < 4) await _addLedger(txn);
            if (from < 5) await _addComponentWarranty(txn);
          }),
        ),
      );

  static Future<void> _addSerialNumber(Transaction db) => db.execute(
    "ALTER TABLE items ADD COLUMN serial_number TEXT NOT NULL DEFAULT ''",
  );

  static Future<void> _addLedger(Transaction db) async {
    await db.execute('ALTER TABLE claims ADD COLUMN follow_up_at INTEGER');
    await db.execute("ALTER TABLE claim_events ADD COLUMN reference TEXT NOT NULL DEFAULT ''");
    await db.execute('''
      CREATE TABLE claim_event_photos (
        event_id TEXT PRIMARY KEY REFERENCES claim_events(id) ON DELETE CASCADE,
        rel_path TEXT NOT NULL,
        name TEXT NOT NULL,
        bytes INTEGER NOT NULL CHECK (bytes BETWEEN 1 AND 20971520)
      )
    ''');
  }

  static Future<void> _addComponentWarranty(Transaction db) async {
    await db.execute('ALTER TABLE items ADD COLUMN component_warranty_until TEXT');
    await db.execute("ALTER TABLE items ADD COLUMN component_warranty_name TEXT NOT NULL DEFAULT ''");
  }

  static Future<void> _createV2(Transaction db) async {
    await db.execute('''
      CREATE TABLE items (
        id TEXT PRIMARY KEY,
        kind TEXT NOT NULL,
        name TEXT NOT NULL,
        source TEXT NOT NULL DEFAULT '',
        subtype TEXT NOT NULL DEFAULT '',
        reference TEXT NOT NULL DEFAULT '',
        notes TEXT NOT NULL DEFAULT '',
        amount_minor INTEGER,
        currency TEXT NOT NULL DEFAULT 'INR',
        starts_on TEXT,
        return_until TEXT,
        cover_until TEXT,
        remind INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        archived_at INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE attachments (
        id TEXT PRIMARY KEY,
        item_id TEXT NOT NULL REFERENCES items(id) ON DELETE CASCADE,
        rel_path TEXT NOT NULL,
        name TEXT NOT NULL,
        bytes INTEGER NOT NULL DEFAULT 0,
        position INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX attachments_item ON attachments(item_id, position)',
    );
    await db.execute('''
      CREATE TABLE claims (
        id TEXT PRIMARY KEY,
        item_id TEXT REFERENCES items(id) ON DELETE SET NULL,
        item_label TEXT NOT NULL,
        type TEXT NOT NULL,
        want TEXT NOT NULL,
        problem TEXT NOT NULL DEFAULT '',
        reference TEXT NOT NULL DEFAULT '',
        opened_on TEXT NOT NULL,
        noticed_on TEXT,
        step INTEGER NOT NULL DEFAULT 0,
        step_since TEXT NOT NULL,
        last_heard_on TEXT,
        settled_on TEXT,
        nudge_days INTEGER NOT NULL DEFAULT 14
      )
    ''');
    await db.execute('''
      CREATE TABLE claim_events (
        id TEXT PRIMARY KEY,
        claim_id TEXT NOT NULL REFERENCES claims(id) ON DELETE CASCADE,
        on_date TEXT NOT NULL,
        kind TEXT NOT NULL,
        text TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX claim_events_claim ON claim_events(claim_id, created_at)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS preferences (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  /// Moves every v1 record into the v2 tables. The old table is renamed to
  /// `records_v1_backup` rather than dropped, so nothing is ever lost.
  static Future<void> _migrateV1ToV2(Transaction db) async {
    await _createV2(db);
    final hasRecords = (await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'records'",
    )).isNotEmpty;
    if (!hasRecords) return;

    final rows = await db.query('records');
    for (final row in rows) {
      final id = row['id']! as String;
      final createdAt = row['created_at']! as int;
      final kind = switch (row['kind']) {
        'receipt' => 'bill',
        'policy' => 'policy',
        _ => 'agreement',
      };
      final amount = row['amount_cents'] as int?;
      await db.insert('items', {
        'id': id,
        'kind': kind,
        'name': row['title'] ?? '',
        'source': row['source'] ?? '',
        'notes': row['notes'] ?? '',
        'amount_minor': amount,
        // v1 entered amounts in US dollars.
        'currency': amount == null ? 'INR' : 'USD',
        'starts_on': row['recorded_on'],
        'cover_until': row['deadline'],
        'remind': 1,
        'created_at': createdAt,
        'updated_at': createdAt,
        'archived_at': row['archived_at'],
      });
      final key = row['attachment_key'] as String?;
      if (key != null) {
        await db.insert('attachments', {
          'id': const Uuid().v4(),
          'item_id': id,
          'rel_path': key,
          'name': row['attachment_name'] ?? 'Original',
          // Unknown in v1; the size is only informational.
          'bytes': 0,
          'position': 0,
          'created_at': createdAt,
        });
      }
    }
    await db.execute('ALTER TABLE records RENAME TO records_v1_backup');
  }
}
