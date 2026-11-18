import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrawer/src/data/vault_controller.dart';
import 'package:paperdrawer/src/data/vault_record.dart';
import 'package:paperdrawer/src/data/vault_repository.dart';
import 'package:paperdrawer/src/ui/app.dart';

void main() {
  testWidgets('iPhone 16 layout supports adding, searching and archiving', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.padding = const FakeViewPadding(top: 177, bottom: 102);
    addTearDown(tester.view.reset);
    final vault = VaultController(_MemoryVault());
    addTearDown(vault.dispose);
    await vault.initialize();
    await tester.pumpWidget(PaperDrawerApp(vault: vault));
    expect(find.text('Your vault'), findsOneWidget);
    expect(find.text('Add your first receipt'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('add-item')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('item-title')),
      'Coffee machine',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('save-item')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-item')));
    await tester.pumpAndSettle();
    expect(find.text('Coffee machine'), findsOneWidget);

    final search = find.byKey(const ValueKey('search-vault'));
    await tester.enterText(search, 'fridge');
    await tester.pumpAndSettle();
    expect(find.text('NO MATCHES'), findsOneWidget);
    await tester.enterText(search, 'coffee');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coffee machine'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive item'));
    await tester.pumpAndSettle();
    expect(find.text('Add your first receipt'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coffee machine'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore to vault'));
    await tester.pumpAndSettle();
    expect(vault.active.single.draft.title, 'Coffee machine');
    expect(tester.takeException(), isNull);
  });
}

class _MemoryVault implements VaultRepository {
  VaultRecord? _record;
  VaultAppearance _theme = VaultAppearance.system;

  @override
  Future<List<VaultRecord>> readAll() async => [?_record];

  @override
  Future<void> save(
    VaultDraft draft, {
    String? id,
    VaultAttachment? import,
  }) async {
    _record = VaultRecord(id: 'test', draft: draft, createdAt: DateTime(2026));
  }

  @override
  Future<void> setArchived(String id, bool archived) async {
    final old = _record!;
    _record = VaultRecord(
      id: old.id,
      draft: old.draft,
      createdAt: old.createdAt,
      archivedAt: archived ? DateTime(2026) : null,
    );
  }

  @override
  Future<VaultAppearance> readTheme() async => _theme;

  @override
  Future<void> setTheme(VaultAppearance mode) async => _theme = mode;
}
