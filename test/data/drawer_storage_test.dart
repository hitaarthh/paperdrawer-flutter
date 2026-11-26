import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrawer/data/services/app_database.dart';
import 'package:paperdrawer/data/services/drawer_storage.dart';
import 'package:paperdrawer/data/services/legacy_claims.dart';
import 'package:paperdrawer/domain/models/item.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

void main() {
  sqfliteFfiInit();
  final project = Uri.parse('https://drawer.example.test');
  final clara = DrawerOwner(project, '11111111-1111-1111-1111-111111111111');
  final john = DrawerOwner(project, '22222222-2222-2222-2222-222222222222');
  late Directory root;
  late DrawerStorage storage;
  late PendingFile original;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('paperdrawer-owners-');
    storage = DrawerStorage(root, factory: databaseFactoryFfi);
    final input = await File(p.join(root.path, 'original.pdf'))
        .writeAsString('original');
    original = PendingFile(path: input.path, name: 'original.pdf');
  });
  tearDown(() => root.delete(recursive: true));

  test(
    'reopens separate drawers, settings and originals for each owner',
    () async {
      var drawer = await storage.open(owner: clara);
      final saved = await drawer.items.create(
        const ItemDraft(kind: ItemKind.policy, name: 'Clara’s policy'),
        files: [original],
      );
      await drawer.settings.setLeadDays(2);
      await drawer.close();
      await expectLater(drawer.items.delete(saved.id), throwsStateError);

      final otherProject = DrawerOwner(
        Uri.parse('https://dev.example.test'),
        '11111111-1111-1111-1111-111111111111',
      );
      for (final owner in [john, otherProject]) {
        final other = await storage.open(owner: owner);
        expect(other.items.items, isEmpty);
        expect(other.settings.leadDays, 7);
        expect(other.settings.pendingSettings, isEmpty);
        expect(
          p.isWithin(other.files.root.path, saved.attachments.single.path),
          isFalse,
        );
        await other.close();
      }

      drawer = await storage.open(owner: clara);
      expect(drawer.items.items.single.id, saved.id);
      expect(
        await File(drawer.items.items.single.attachments.single.path)
            .readAsString(),
        'original',
      );
      expect(drawer.settings.leadDays, 2);
      expect(drawer.settings.pendingSettings, hasLength(1));
      await drawer.close();
    },
  );

  test(
    'explicit legacy import preserves IDs, files and claims without duplicates',
    () async {
      final legacy = await storage.open();
      final item = await legacy.items.create(
        const ItemDraft(kind: ItemKind.bill, name: 'Older bill'),
        files: [original],
      );
      await legacy.items.setArchived(item.id, true);
      await legacy.settings.setLeadDays(14);
      final sourceFile = item.attachments.single.path;
      await legacy.close();
      final sourcePhoto = await _seedClaim(root, itemId: item.id);

      var drawer = await storage.open(owner: clara);
      expect(drawer.items.items, isEmpty);
      expect(await storage.canImportLegacy(clara, drawer), isTrue);
      await storage.importLegacy(clara, drawer);
      await storage.importLegacy(clara, drawer);
      expect(await storage.canImportLegacy(clara, drawer), isFalse);
      await drawer.close();

      drawer = await storage.open(owner: clara);
      expect(drawer.items.archived.single.id, item.id);
      final claims = await drawer.legacyClaims.read();
      expect(claims.claims.single['id'], 'claim-1');
      expect(claims.claims.single['item_id'], item.id);
      expect(claims.events.single['id'], 'event-1');
      final photo = claims.eventPhotos.single['rel_path']! as String;
      expect(photo, isNot(p.join('claim-photos', 'event-1.jpg')));
      // Reopening an account drawer keeps originals that rows refer to.
      expect(
        await File(drawer.files.absolute(photo)).readAsString(),
        'photo',
      );
      expect(await sourcePhoto.exists(), isTrue);
      final importedFile = drawer.items.items.single.attachments.single.path;
      expect(importedFile, isNot(sourceFile));
      expect(await File(importedFile).readAsString(), 'original');
      expect(await File(sourceFile).exists(), isTrue);
      expect(drawer.settings.leadDays, 14);
      expect(drawer.settings.pendingSettings, isEmpty);
      await drawer.close();

      final other = await storage.open(owner: john);
      expect(await storage.canImportLegacy(john, other), isFalse);
      await expectLater(
        storage.importLegacy(john, other),
        throwsFormatException,
      );
      expect(other.items.items, isEmpty);
      await other.close();
      await expectLater(storage.open(), throwsFormatException);
    },
  );

  test(
    'reopening recovers abandoned account originals and keeps linked files',
    () async {
      var drawer = await storage.open(owner: clara);
      final item = await drawer.items.create(
        const ItemDraft(kind: ItemKind.bill, name: 'Warranty'),
        files: [original],
      );
      final saved = File(item.attachments.single.path);
      final orphan = await File(
        p.join(
          saved.parent.path,
          '${const Uuid().v4()}-${const Uuid().v4()}.pdf',
        ),
      ).writeAsString('partial');
      await drawer.close();

      drawer = await storage.open(owner: clara);
      expect(await saved.exists(), isTrue);
      expect(await orphan.exists(), isFalse);
      await drawer.close();
    },
  );

  test('reopening an account drawer keeps its claim photos', () async {
    var drawer = await storage.open(owner: clara);
    await drawer.close();
    final folder = Directory(drawer.files.root.path);
    final photo = await _seedClaim(folder);

    drawer = await storage.open(owner: clara);
    expect((await drawer.legacyClaims.read()).eventPhotos, hasLength(1));
    await drawer.close();
    expect(await photo.readAsString(), 'photo');
  });

  test('account folder keys reject path traversal', () {
    expect(() => DrawerOwner(project, '../john'), throwsFormatException);
  });
}

/// Writes one claim, one event and its photo into the drawer at [folder], as
/// design-v1 stored them.
Future<File> _seedClaim(Directory folder, {String? itemId}) async {
  final photo = File(p.join(folder.path, 'claim-photos', 'event-1.jpg'));
  await photo.parent.create(recursive: true);
  await photo.writeAsString('photo');
  final db = await AppDatabase.open(
    p.join(folder.path, 'vault.sqlite'),
    factory: databaseFactoryFfi,
  );
  try {
    await db.insert(LegacyClaimTables.claims, {
      'id': 'claim-1',
      'item_id': itemId,
      'item_label': 'Older bill',
      'type': 'repair',
      'want': 'repair',
      'opened_on': '2026-11-20',
      'step_since': '2026-11-20',
    });
    await db.insert(LegacyClaimTables.events, {
      'id': 'event-1',
      'claim_id': 'claim-1',
      'on_date': '2026-11-20',
      'kind': 'opened',
      'created_at': 1795000000000,
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
