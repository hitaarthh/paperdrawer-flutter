import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:paperdrawer/data/repositories/settings_repository.dart';
import 'package:paperdrawer/data/services/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory dir;
  late String path;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('pd-settings-');
    path = p.join(dir.path, 'vault.sqlite');
  });

  tearDown(() => dir.delete(recursive: true));

  Future<(Database, SettingsRepository)> open() async {
    final db = await AppDatabase.open(path, factory: databaseFactoryFfi);
    final settings = SettingsRepository(db);
    await settings.load();
    return (db, settings);
  }

  test('the reminders offer answer persists across a reopen', () async {
    var (db, settings) = await open();
    expect(settings.remindersOffered, isFalse);
    expect(settings.remindersOn, isFalse);

    var notified = 0;
    settings.addListener(() => notified++);
    await settings.markRemindersOffered();
    await settings.setRemindersOn(true);
    expect(settings.remindersOffered, isTrue);
    expect(notified, 2);
    await db.close();

    (db, settings) = await open();
    expect(settings.remindersOffered, isTrue);
    expect(settings.remindersOn, isTrue);
    // Stored in the key/value preferences table: no schema change.
    final rows = await db.query(
      'preferences',
      where: 'key = ?',
      whereArgs: ['reminders_offered'],
    );
    expect(rows.single['value'], '1');
    expect(await db.getVersion(), AppDatabase.version);
    await db.close();
  });

  test('erasing the drawer clears the offer answer', () async {
    final (db, settings) = await open();
    await settings.markRemindersOffered();
    await settings.eraseAll();
    expect(settings.remindersOffered, isFalse);
    await db.close();
  });
}
