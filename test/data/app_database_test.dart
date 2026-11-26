import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:paperdrawer/data/repositories/item_repository.dart';
import 'package:paperdrawer/data/services/app_database.dart';
import 'package:paperdrawer/data/services/file_store.dart';
import 'package:paperdrawer/data/services/reminder_scheduler.dart';
import 'package:paperdrawer/domain/item_status.dart';
import 'package:paperdrawer/domain/models/item.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test(
    'upgrading the drawer keeps previous bills and their originals',
    () async {
      final directory = await Directory.systemTemp.createTemp('pd-v2-');
      addTearDown(() => directory.delete(recursive: true));
      final path = p.join(directory.path, 'vault.sqlite');
      final old = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (db, _) async {
            await db.execute(
              'CREATE TABLE items (id TEXT PRIMARY KEY, name TEXT)',
            );
            await db.execute('''
            CREATE TABLE attachments (
              id TEXT PRIMARY KEY,
              item_id TEXT REFERENCES items(id) ON DELETE CASCADE
            )
          ''');
            await db.execute('CREATE TABLE claims (id TEXT PRIMARY KEY)');
            await db.execute('CREATE TABLE claim_events (id TEXT PRIMARY KEY)');
            await db.insert('claims', {'id': 'existing-claim'});
            await db.insert('claim_events', {'id': 'existing-entry'});
            await db.insert('items', {'id': 'bill', 'name': 'Air cooler'});
            await db.insert('attachments', {'id': 'photo', 'item_id': 'bill'});
          },
        ),
      );
      await old.close();

      final upgraded = await AppDatabase.open(
        path,
        factory: databaseFactoryFfi,
      );
      addTearDown(upgraded.close);
      expect(await upgraded.getVersion(), AppDatabase.version);
      expect((await upgraded.query('items')).single, {
        'id': 'bill',
        'name': 'Air cooler',
        'serial_number': '',
        'component_warranty_until': null,
        'component_warranty_name': '',
        'reminder_at': null,
        'coverage_renews': null,
      });
      expect((await upgraded.query('attachments')).single['item_id'], 'bill');
      await upgraded.update('items', {
        'serial_number': 'AQ-118/3',
        'component_warranty_until': '2031-11-14',
        'component_warranty_name': 'Compressor',
      });
      expect((await upgraded.query('claims')).single['follow_up_at'], isNull);
      expect((await upgraded.query('claim_events')).single['reference'], '');
      expect(
        (await upgraded.query('items')).single['serial_number'],
        'AQ-118/3',
      );
    },
  );
  test('reopening keeps the chosen date meaning, reminder and replacement original', () async {
    final directory = await Directory.systemTemp.createTemp('pd-reminders-');
    addTearDown(() => directory.delete(recursive: true));
    final path = p.join(directory.path, 'drawer.sqlite');
    Future<PendingFile> file(String name) async {
      final original = File(p.join(directory.path, name));
      await original.writeAsString('%PDF-1.7');
      return PendingFile(path: original.path, name: name);
    }

    final fileStore = FileStore(directory);
    final db = await AppDatabase.open(path, factory: databaseFactoryFfi);
    final items = ItemRepository(db, fileStore);
    final at = DateTime(2026, 11, 20, 16, 45);
    final draft = ItemDraft(
      kind: ItemKind.policy,
      name: 'Home insurance',
      coverUntil: DateTime.utc(2026, 12, 1),
      coverageRenews: false,
      reminderAt: at,
    );
    final item = await items.create(
      draft,
      files: [await file('policy.pdf'), await file('appendix.pdf')],
    );
    await items.update(
      item.id,
      draft,
      addFiles: [await file('revision.pdf')],
      removeAttachmentIds: {item.attachments.first.id},
      prependOriginal: true,
    );
    items.dispose();
    await db.close();

    final reopened = await AppDatabase.open(path, factory: databaseFactoryFfi);
    addTearDown(reopened.close);
    final restored = ItemRepository(reopened, fileStore);
    addTearDown(restored.dispose);
    await restored.load();
    final stored = restored.active.single;
    expect(stored.attachments.map((a) => a.name), [
      'revision.pdf',
      'appendix.pdf',
    ]);
    expect(
      await File(stored.attachments.first.path).readAsString(),
      '%PDF-1.7',
    );
    expect(await File(item.attachments.first.path).exists(), isFalse);
    expect(stored.draft.coverageRenews, isFalse);
    expect(stored.draft.reminderAt!.isAtSameMomentAs(at), isTrue);
    expect(windowsOf(stored).single.ticketKicker, 'POLICY EXPIRES');

    List<PlannedReminder> reminders(DateTime now) => planReminders(
      items: restored.active,
      leadDays: 7,
      now: now,
    );
    expect(reminders(DateTime(2026, 11, 19)).single.at, at);
    expect(reminders(DateTime(2026, 11, 21)), isEmpty);
  });
}
