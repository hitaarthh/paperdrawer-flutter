import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:paperdrawer/data/services/app_database.dart';
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
}
