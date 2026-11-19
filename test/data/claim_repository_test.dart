import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrawer/data/repositories/claim_repository.dart';
import 'package:paperdrawer/data/services/app_database.dart';
import 'package:paperdrawer/data/services/file_store.dart';
import 'package:paperdrawer/domain/formats.dart';
import 'package:paperdrawer/domain/models/claim.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test(
    'sending a recommended draft advances and logs the new recipient',
    () async {
      final dir = await Directory.systemTemp.createTemp('pd-claim-');
      addTearDown(() => dir.delete(recursive: true));
      final path = p.join(dir.path, 'vault.sqlite');
      final opened = DateTime.utc(2026, 11, 4);
      final due = addDays(opened, 14);

      final db = await AppDatabase.open(path, factory: databaseFactoryFfi);
      final claims = ClaimRepository(db, FileStore(dir));
      try {
        await db.insert('items', {
          'id': 'laptop',
          'name': 'Laptop',
          'kind': 'bill',
          'created_at': 0,
          'updated_at': 0,
        });
        final claim = await claims.start(
          itemId: 'laptop',
          itemLabel: 'Laptop',
          type: ClaimType.repair,
          want: ClaimWant.repair,
          problem: 'Loose hinge',
          today: opened,
        );
        await expectLater(
          claims.logSent(claim.id, addDays(due, -1), step: 1),
          throwsFormatException,
        );
        expect(claims.claims.single.step, 0);
        expect(claims.claims.single.events, hasLength(1));
        await claims.logSent(claim.id, due, step: 1);
      } finally {
        claims.dispose();
        await db.close();
      }

      final reopened = await AppDatabase.open(
        path,
        factory: databaseFactoryFfi,
      );
      addTearDown(reopened.close);
      final persisted = ClaimRepository(reopened, FileStore(dir));
      addTearDown(persisted.dispose);
      await persisted.load();
      final updated = persisted.claims.single;
      expect(updated.step, 1);
      expect(updated.stepSince, due);
      expect(updated.nudgeDays, 30);
      expect(updated.status(due), ClaimStatus.waiting);
      expect(updated.events.map((event) => event.kind), [
        ClaimEventKind.sent,
        ClaimEventKind.step,
        ClaimEventKind.opened,
      ]);
      expect(
        updated.events.first.text,
        'Sent the message to Grievance officer',
      );
    },
  );
}
