import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrawer/data/services/app_database.dart';
import 'package:paperdrawer/data/services/drawer_storage.dart';
import 'package:paperdrawer/data/services/exporter.dart';
import 'package:paperdrawer/data/services/legacy_claims.dart';
import 'package:paperdrawer/data/services/today.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Writes one claim with one event and its photo straight into the drawer's
/// database, the way design-v1 left them.
Future<File> seedClaim(Directory root) async {
  final photo = File(p.join(root.path, 'claim-photos', 'event-1.jpg'));
  await photo.parent.create(recursive: true);
  await photo.writeAsString('photo');
  final db = await AppDatabase.open(
    p.join(root.path, 'vault.sqlite'),
    factory: databaseFactoryFfi,
  );
  try {
    await db.insert(LegacyClaimTables.claims, {
      'id': 'claim-1',
      'item_id': null,
      'item_label': 'Refrigerator',
      'type': 'repair',
      'want': 'repair',
      'problem': 'Not cooling',
      'opened_on': '2026-11-01',
      'step_since': '2026-11-01',
      'follow_up_at': 1795000000000,
    });
    await db.insert(LegacyClaimTables.events, {
      'id': 'event-1',
      'claim_id': 'claim-1',
      'on_date': '2026-11-02',
      'kind': 'call',
      'text': 'Called the service centre',
      'reference': 'SR-12',
      'created_at': 1794000000000,
    });
    await db.insert(LegacyClaimTables.eventPhotos, {
      'event_id': 'event-1',
      'rel_path': p.join('claim-photos', 'event-1.jpg'),
      'name': 'Job sheet.jpg',
      'bytes': 5,
    });
  } finally {
    await db.close();
  }
  return photo;
}

void main() {
  sqfliteFfiInit();

  late Directory root;
  late DrawerStorage storage;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('pd-legacy-claims-');
    storage = DrawerStorage(root, factory: databaseFactoryFfi);
  });

  tearDown(() => root.delete(recursive: true));

  test('a drawer with claim rows opens and keeps every row', () async {
    await seedClaim(root);

    final drawer = await storage.open();
    final rows = await drawer.legacyClaims.read();
    await drawer.close();

    expect(rows.claims.single['id'], 'claim-1');
    expect(rows.claims.single['problem'], 'Not cooling');
    expect(rows.events.single['reference'], 'SR-12');
    expect(rows.eventPhotos.single['name'], 'Job sheet.jpg');
  });

  test('clearing the drawer removes claim rows and their photos', () async {
    final photo = await seedClaim(root);

    var drawer = await storage.open();
    await drawer.legacyClaims.eraseAll();
    await drawer.close();

    drawer = await storage.open();
    final rows = await drawer.legacyClaims.read();
    await drawer.close();
    expect(rows.claims, isEmpty);
    expect(rows.events, isEmpty);
    expect(rows.eventPhotos, isEmpty);
    expect(await photo.exists(), isFalse);
  });

  test('a closed drawer refuses to read or erase claim rows', () async {
    final photo = await seedClaim(root);
    final drawer = await storage.open();
    await drawer.close();

    await expectLater(drawer.legacyClaims.read(), throwsStateError);
    await expectLater(drawer.legacyClaims.eraseAll(), throwsStateError);
    expect(await photo.exists(), isTrue);
  });

  test('export includes the raw claim rows and claim photos', () async {
    await seedClaim(root);
    final drawer = await storage.open();
    final rows = await drawer.legacyClaims.read();
    final cache = await Directory(p.join(root.path, 'cache')).create();
    final exporter = Exporter(
      drawer.files,
      today: Today(() => DateTime(2026, 11, 25)),
      temporaryDirectory: () async => cache,
    );

    final file = await exporter.exportEverything(items: [], claims: rows);
    await drawer.close();

    final zip = ZipDecoder().decodeBytes(await file.readAsBytes());
    String text(String name) => utf8.decode(zip.findFile(name)!.content);
    final json = jsonDecode(text('paperdrawer.json')) as Map<String, Object?>;
    final claims = json['legacy_claims']! as Map<String, Object?>;
    expect((claims['claims']! as List).single, containsPair('id', 'claim-1'));
    expect(
      (claims['claim_events']! as List).single,
      containsPair('text', 'Called the service centre'),
    );
    final photo = (claims['claim_event_photos']! as List).single as Map;
    expect(photo['path'], 'claim-photos/event-1/Job sheet.jpg');
    expect(text(photo['path']! as String), 'photo');
    await exporter.discardExport(file);
  });
}
