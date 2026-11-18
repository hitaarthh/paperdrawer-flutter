import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:paperdrawer/data/services/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('upgrading the drawer keeps previous bills and their originals', () async {
    final directory = await Directory.systemTemp.createTemp('pd-v2-');
    addTearDown(() => directory.delete(recursive: true));
    final path = p.join(directory.path, 'vault.sqlite');
    final old = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, _) async {
          await db.execute('CREATE TABLE items (id TEXT PRIMARY KEY, name TEXT)');
          await db.execute('''
            CREATE TABLE attachments (
              id TEXT PRIMARY KEY,
              item_id TEXT REFERENCES items(id) ON DELETE CASCADE
            )
          ''');
          await db.insert('items', {'id': 'bill', 'name': 'Air cooler'});
          await db.insert('attachments', {'id': 'photo', 'item_id': 'bill'});
        },
      ),
    );
    await old.close();

    final upgraded = await AppDatabase.open(path, factory: databaseFactoryFfi);
    addTearDown(upgraded.close);
    expect(await upgraded.getVersion(), AppDatabase.version);
    expect((await upgraded.query('items')).single, {
      'id': 'bill',
      'name': 'Air cooler',
      'serial_number': '',
    });
    expect((await upgraded.query('attachments')).single['item_id'], 'bill');
    await upgraded.update('items', {'serial_number': 'AQ-118/3'});
    expect((await upgraded.query('items')).single['serial_number'], 'AQ-118/3');
  });
}
