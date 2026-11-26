import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrawer/data/repositories/item_repository.dart';
import 'package:paperdrawer/data/services/app_database.dart';
import 'package:paperdrawer/data/services/file_store.dart';
import 'package:paperdrawer/data/services/reminder_scheduler.dart';
import 'package:paperdrawer/domain/item_status.dart';
import 'package:paperdrawer/domain/models/item.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('the component warranty persists and gets its own reminder', () async {
    final directory = await Directory.systemTemp.createTemp('pd-component-');
    addTearDown(() => directory.delete(recursive: true));
    final path = p.join(directory.path, 'vault.sqlite');
    final files = FileStore(directory);
    final first = await AppDatabase.open(path, factory: databaseFactoryFfi);
    final items = ItemRepository(first, files);
    final saved = await items.create(
      ItemDraft(
        kind: ItemKind.bill,
        name: 'Split AC',
        startsOn: DateTime.utc(2026, 11, 14),
        coverUntil: DateTime.utc(2027, 11, 14),
        componentWarrantyUntil: DateTime.utc(2031, 11, 14),
        componentWarrantyName: ' Compressor ',
      ),
    );
    items.dispose();
    await first.close();

    final second = await AppDatabase.open(path, factory: databaseFactoryFfi);
    addTearDown(second.close);
    final restored = ItemRepository(second, files);
    addTearDown(restored.dispose);
    await restored.load();
    final bill = restored.byId(saved.id)!;

    final windows = windowsOf(bill);
    expect(windows.map((window) => window.type), [
      WindowType.warranty,
      WindowType.componentWarranty,
    ]);
    expect(windows.last.label, 'COMPRESSOR WARRANTY');
    expect(windows.last.end, DateTime.utc(2031, 11, 14));
    final reminders = planReminders(
      items: [bill],
      leadDays: 7,
      now: DateTime(2027, 11, 1),
    );
    expect(reminders.map((reminder) => reminder.at), [
      DateTime(2027, 11, 7, 9),
      DateTime(2031, 11, 7, 9),
    ]);
  });
}
