import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrawer/src/data/sqlite_vault_repository.dart';
import 'package:paperdrawer/src/data/vault_record.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test(
    'retains records, date, private attachment and archived state on reopen',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'paperdrawer-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final picked = await File(p.join(directory.path, 'receipt.pdf'))
          .writeAsString('%PDF-test');
      final vaultDirectory = Directory(p.join(directory.path, 'vault'));
      var vault = await SqliteVaultRepository.open(
        vaultDirectory,
        factory: databaseFactoryFfi,
      );
      addTearDown(() => vault.close());
      await vault.save(
        VaultDraft(
          kind: RecordKind.receipt,
          title: ' Coffee machine ',
          deadline: DateTime(2027, 3, 12),
          amountCents: 12499,
        ),
        import: VaultAttachment(path: picked.path, name: 'receipt.pdf'),
      );
      final record = (await vault.readAll()).single;
      expect(record.draft.title, 'Coffee machine');
      expect(record.attachment!.path, isNot(picked.path));
      await picked.delete();
      await vault.setArchived(record.id, true);
      await vault.setTheme(VaultAppearance.dark);
      await vault.close();

      vault = await SqliteVaultRepository.open(
        vaultDirectory,
        factory: databaseFactoryFfi,
      );
      final restored = (await vault.readAll()).single;
      expect(restored.isArchived, isTrue);
      expect(restored.draft.deadline, DateTime.utc(2027, 3, 12));
      expect(restored.draft.amountCents, 12499);
      expect(await File(restored.attachment!.path).readAsString(), '%PDF-test');
      expect(await vault.readTheme(), VaultAppearance.dark);

      await vault.save(
        const VaultDraft(kind: RecordKind.receipt, title: 'Espresso machine'),
        id: restored.id,
      );
      await vault.setArchived(restored.id, false);
      final edited = (await vault.readAll()).single;
      expect(edited.isArchived, isFalse);
      expect(edited.draft.title, 'Espresso machine');
      expect(edited.attachment!.path, restored.attachment!.path);
    },
  );

  test('rejects unsupported import without adding a record', () async {
    final directory = await Directory.systemTemp.createTemp(
      'paperdrawer-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final vault = await SqliteVaultRepository.open(
      directory,
      factory: databaseFactoryFfi,
    );
    addTearDown(vault.close);
    final picked = await File(p.join(directory.path, 'receipt.txt'))
        .writeAsString('text');

    await expectLater(
      vault.save(
        const VaultDraft(kind: RecordKind.receipt, title: 'Receipt'),
        import: VaultAttachment(path: picked.path, name: 'receipt.txt'),
      ),
      throwsFormatException,
    );
    expect(await vault.readAll(), isEmpty);
    expect(await picked.exists(), isTrue);
  });
}
