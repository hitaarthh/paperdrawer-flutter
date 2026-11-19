import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrawer/data/repositories/claim_repository.dart';
import 'package:paperdrawer/data/services/app_database.dart';
import 'package:paperdrawer/data/services/file_store.dart';
import 'package:paperdrawer/data/services/ledger_pdf.dart';
import 'package:paperdrawer/data/services/reminder_scheduler.dart';
import 'package:paperdrawer/domain/models/claim.dart';
import 'package:paperdrawer/domain/models/item.dart';
import 'package:paperdrawer/domain/models/ledger.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  test(
    'ledger persists dated entries, photo and follow-up across a reopen',
    () async {
      final root = await Directory.systemTemp.createTemp('pd-ledger-');
      addTearDown(() => root.delete(recursive: true));
      final path = p.join(root.path, 'vault.sqlite');
      final files = FileStore(root);
      final now = DateTime(2026, 11, 18, 9, 15);
      final followUp = DateTime(2026, 11, 23, 10, 35);
      final bill = Item(
        id: 'bill',
        createdAt: now,
        draft: const ItemDraft(kind: ItemKind.bill, name: 'Air cooler'),
      );
      final input = await File(p.join(root.path, 'receipt.jpg'))
          .writeAsBytes([1, 2, 3]);
      final db = await AppDatabase.open(path, factory: databaseFactoryFfi);
      final repository = ClaimRepository(db, files);
      late final String claimId;
      try {
        await db.insert('items', {
          'id': bill.id,
          'name': bill.name,
          'kind': bill.kind.name,
          'created_at': 0,
          'updated_at': 0,
        });
        final opened = await Future.wait([
          repository.openLedger(bill, now),
          repository.openLedger(bill, now),
        ]);
        claimId = opened.first.id;
        expect(opened.last.id, claimId);

        await expectLater(
          repository.addEntry(
            claimId,
            LedgerDraft(
              kind: LedgerKind.note,
              date: now,
              text: ' ',
              reference: '',
              photo: PendingFile(path: input.path, name: 'receipt.jpg'),
            ),
            now,
          ),
          throwsFormatException,
        );
        expect(repository.byId(claimId)!.ledger, hasLength(1));
        expect(
          Directory(p.join(root.path, 'claim-photos')).existsSync(),
          isFalse,
        );

        await repository.addEntry(
          claimId,
          LedgerDraft(
            kind: LedgerKind.call,
            date: DateTime(2026, 11, 17),
            text: '  Accepted the return. ',
            reference: '  SR-1142  ',
            photo: PendingFile(path: input.path, name: 'receipt.jpg'),
            followUp: followUp,
          ),
          now,
        );
        await repository.addEntry(
          claimId,
          LedgerDraft(
            kind: LedgerKind.refund,
            date: now,
            text: 'Refund received.',
            reference: '',
          ),
          now,
        );
        final storedPhoto = (await db.query('claim_event_photos')).single;
        expect(p.isRelative(storedPhoto['rel_path']! as String), isTrue);
      } finally {
        repository.dispose();
        await db.close();
      }

      final reopened = await AppDatabase.open(
        path,
        factory: databaseFactoryFfi,
      );
      addTearDown(reopened.close);
      final persisted = ClaimRepository(reopened, files);
      addTearDown(persisted.dispose);
      await persisted.load();

      final claim = persisted.byId(claimId)!;
      expect(claim.ledger.map((e) => e.text), [
        'Refund received.',
        'Claim opened',
        'Accepted the return.',
      ]);
      expect(claim.ledger.last.reference, 'SR-1142');
      expect(claim.ledger.last.kind, LedgerKind.call);
      expect(claim.followUp, followUp);
      final photo = claim.events.last.photo!;
      expect(await File(photo.path).readAsBytes(), [1, 2, 3]);
      expect(
        planReminders(
          items: [],
          claims: [claim],
          leadDays: 7,
          now: now,
        ).single.at,
        followUp,
      );

      await persisted.settle(claimId, now);
      expect(persisted.byId(claimId)!.followUp, isNull);
      expect(
        planReminders(
          items: [],
          claims: persisted.claims,
          leadDays: 7,
          now: now,
        ),
        isEmpty,
      );
      await persisted.delete(claimId);
      expect(await File(photo.path).exists(), isFalse);
      expect(await input.exists(), isTrue);
    },
  );

  test('legacy claims only notify when a follow-up is explicitly set', () {
    final opened = DateTime(2026, 11, 19);
    final claim = Claim(
      id: 'legacy',
      type: ClaimType.repair,
      want: ClaimWant.repair,
      itemLabel: 'Cooler',
      problem: 'The motor stopped.',
      openedOn: opened,
      step: 0,
      stepSince: opened,
    );

    expect(
      planReminders(items: [], claims: [claim], leadDays: 7, now: opened),
      isEmpty,
    );
  });

  test('exports a paginated PDF with references and file names', () async {
    final now = DateTime(2026, 11, 18);
    final pdf = await buildLedgerPdf(
      title: 'Cooler / replacement',
      opened: now,
      settled: null,
      entries: [
        for (var n = 0; n < 30; n++)
          LedgerEntry(
            id: '$n',
            date: now,
            kind: LedgerKind.call,
            text: List.filled(56, 'Technician visit pending.').join(' '),
            reference: 'SR-$n',
          ),
      ],
      files: ['receipt.jpg'],
      serial: 'AC5T-88310-KX',
    );
    final bytes = await pdf.readAsBytes();
    expect(pdf.name, 'Cooler - replacement-ledger.pdf');
    expect(pdf.mimeType, 'application/pdf');
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(
      RegExp(r'/Type\s*/Page\b').allMatches(String.fromCharCodes(bytes)).length,
      greaterThan(1),
    );
  });
}
