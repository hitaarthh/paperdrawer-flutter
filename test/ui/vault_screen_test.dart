import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:paperdrawer/app.dart';
import 'package:paperdrawer/data/repositories/item_repository.dart';
import 'package:paperdrawer/data/repositories/settings_repository.dart';
import 'package:paperdrawer/data/services/drawer_actions.dart';
import 'package:paperdrawer/data/services/exporter.dart';
import 'package:paperdrawer/data/services/file_store.dart';
import 'package:paperdrawer/data/services/legacy_claims.dart';
import 'package:paperdrawer/data/services/text_recognizer.dart';
import 'package:paperdrawer/data/services/today.dart';
import 'package:paperdrawer/domain/formats.dart';
import 'package:paperdrawer/domain/item_status.dart';
import 'package:paperdrawer/domain/models/item.dart';
import 'package:paperdrawer/routing/router.dart';
import 'package:paperdrawer/ui/core/widgets/vault_ticket.dart';

// A Wednesday, so a return window that closes in 2 days reads "FRI 20 NOV".
final _today = DateTime.utc(2026, 11, 18);

void main() {
  group('empty vault', () {
    for (final scale in [1.0, 1.3]) {
      testWidgets('shows the welcome receipt at ${scale}x', (tester) async {
        await _launch(tester, _Items([]), scale: scale);

        expect(find.text('000 ITEMS · NOTHING DUE'), findsNothing);
        expect(find.text('Your drawer'), findsOneWidget);
        expect(find.text('Add your first file.'), findsOneWidget);
        expect(_key('drawer-add-first-file'), findsOneWidget);
        expect(_key('vault-search'), findsNothing);
        expect(_key('drawer-notifications'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('empty Drawer and dock open the same Files form', (
      tester,
    ) async {
      await _launch(tester, _Items([]));
      await _tap(tester, 'drawer-add-first-file');
      expect(find.text('Choose from Files'), findsOneWidget);
      await _tap(tester, 'close-button');
      await _tap(tester, 'scan-or-add');
      expect(find.text('Choose from Files'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('full vault', () {
    for (final scale in [1.0, 1.3]) {
      testWidgets('lays out every section at ${scale}x', (tester) async {
        await _launch(tester, _fullItems(), scale: scale);

        expect(find.text('Your drawer'), findsOneWidget);
        expect(_key('vault-search'), findsOneWidget);
        expect(find.text('5 FILES'), findsOneWidget);
        expect(find.text('DUE NEXT'), findsNothing);
        expect(find.byType(VaultTicket), findsNothing);
        await tester.ensureVisible(_key('vault-filter-expired'));
        await tester.pumpAndSettle();
        expect(find.text('EXPIRED 0'), findsOneWidget);
        expect(find.text('SORTED BY WHAT’S DUE FIRST'), findsOneWidget);

        for (final id in ['earbuds', 'policy', 'puc', 'washer', 'laptop']) {
          await tester.scrollUntilVisible(
            _key('vault-item-$id'),
            160,
            scrollable: find
                .byWidgetPredicate(
                  (w) =>
                      w is Scrollable && w.axisDirection == AxisDirection.down,
                )
                .first,
          );
          await tester.pumpAndSettle();
          expect(_key('vault-item-$id'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
      'bill detail shows the original, coverage, and saved facts at 130%',
      (tester) async {
        final bill = Item(
          id: 'fan',
          createdAt: _today,
          draft: ItemDraft(
            kind: ItemKind.bill,
            name: 'Ceiling fan',
            source: 'Hardware store',
            reference: 'INV 216',
            serialNumber: 'FAN-230',
            startsOn: addDays(_today, -5),
            returnUntil: addDays(_today, 2),
            coverUntil: addMonths(_today, 10),
          ),
          attachments: const [
            Attachment(
              id: 'receipt',
              path: '/tmp/receipt.pdf',
              name: 'Receipt.pdf',
              bytes: 120,
            ),
          ],
        );
        await _launch(tester, _Items([bill]), scale: 1.3);
        await _tap(tester, 'vault-item-fan');

        expect(find.text('Ceiling fan'), findsOneWidget);
        expect(find.text('20 Nov 2026'), findsOneWidget);
        final verticalScroll = find
            .byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            )
            .first;
        for (final section in ['ORIGINAL FILE', 'FAN-230', 'Coverage']) {
          await tester.scrollUntilVisible(
            find.text(section),
            170,
            scrollable: verticalScroll,
          );
          expect(find.text(section), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Home shows the next dates within two weeks and Drawer keeps its Due soon filter',
      (tester) async {
        await _launch(
          tester,
          _fullItems(),
          startAtHome: true,
          scale: 1.3,
        );

        final first = tester.widget<VaultTicket>(
          _key('home-ticket-earbuds/returnWindow'),
        );
        expect(first.tone, VaultTicketTone.signal);
        expect(first.number, '02');
        expect(first.kicker, 'RETURN WINDOW CLOSES · FRI 20 NOV');
        final second = tester.widget<VaultTicket>(
          _key('home-ticket-policy/policyYear'),
        );
        expect(second.tone, VaultTicketTone.paper);
        expect(second.number, '12');
        expect(_key('home-ticket-puc/validity'), findsNothing);

        await _tap(tester, 'vault-tab');
        expect(find.text('Your drawer'), findsOneWidget);
        await _tap(tester, 'vault-filter-due');
        expect(find.text('DUE SOON 4'), findsOneWidget);
        expect(_key('vault-item-laptop'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('a Home ticket opens its item', (tester) async {
      await _launch(tester, _fullItems(), startAtHome: true);

      await _tap(tester, 'home-ticket-earbuds/returnWindow');
      expect(_key('item-edit'), findsOneWidget);
      expect(_key('drawer-notifications'), findsNothing);
      await _tap(tester, 'back-button');
      expect(_key('coming-up-list'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Home scrolls the last deadline clear of the glass bar', (
      tester,
    ) async {
      final items = _Items([
        for (var i = 0; i < 8; i++)
          Item(
            id: 'due-$i',
            createdAt: _today,
            draft: ItemDraft(
              kind: ItemKind.bill,
              name: 'Item number $i with a longer name',
              coverUntil: addDays(_today, i),
            ),
          ),
      ]);
      await _launch(
        tester,
        items,
        startAtHome: true,
        scale: 1.3,
      );
      final scroll = find.descendant(
        of: _key('coming-up-list'),
        matching: find.byType(Scrollable),
      );
      final last = _key('home-ticket-due-7/warranty');
      await tester.scrollUntilVisible(
        last.hitTestable(),
        240,
        scrollable: scroll,
      );
      await tester.pumpAndSettle();
      expect(last.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('filter tabs and search narrow the list', (tester) async {
      await _launch(tester, _fullItems());

      await _tap(tester, 'vault-filter-undated');
      expect(find.text('Every file has a tracked date'), findsOneWidget);
      expect(_key('vault-item-earbuds'), findsNothing);
      await _tap(tester, 'vault-filter-expired');
      expect(find.text('No expired files'), findsOneWidget);
      await _tap(tester, 'vault-filter-all');

      await tester.scrollUntilVisible(
        _key('vault-search'),
        -150,
        scrollable: find
            .byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            )
            .first,
      );
      await tester.enterText(_key('vault-search'), 'gupta');
      await tester.pumpAndSettle();
      expect(_key('vault-item-washer'), findsOneWidget);
      expect(_key('vault-item-earbuds'), findsNothing);
      expect(_key('vault-due-next'), findsNothing);
      expect(find.text('ALL 1'), findsOneWidget);

      await tester.enterText(_key('vault-search'), 'nothing like this');
      await tester.pumpAndSettle();
      expect(find.text('Nothing matches “nothing like this”'), findsOneWidget);
      await _tap(tester, 'vault-clear-search');
      expect(_key('vault-item-earbuds'), findsOneWidget);
      expect(find.text('ALL 5'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

_Items _fullItems() => _Items([
  Item(
    id: 'earbuds',
    createdAt: addDays(_today, -8),
    draft: ItemDraft(
      kind: ItemKind.bill,
      name: 'Wireless earbuds',
      source: 'Online order',
      amountMinor: 299900,
      startsOn: addDays(_today, -8),
      returnUntil: addDays(_today, 2),
      coverUntil: addMonths(_today, 12),
    ),
  ),
  Item(
    id: 'policy',
    createdAt: _today,
    draft: ItemDraft(
      kind: ItemKind.policy,
      name: 'Family health policy',
      source: 'Shield General Insurance',
      amountMinor: 2460000,
      coverUntil: addDays(_today, 12),
    ),
  ),
  Item(
    id: 'puc',
    createdAt: _today,
    draft: ItemDraft(
      kind: ItemKind.vehicle,
      subtype: 'PUC certificate',
      name: 'Bike pollution check',
      amountMinor: 10000,
      coverUntil: addDays(_today, 15),
    ),
  ),
  Item(
    id: 'washer',
    createdAt: _today,
    draft: ItemDraft(
      kind: ItemKind.bill,
      name: 'Washing machine',
      source: 'Gupta Home Appliances',
      amountMinor: 2750000,
      startsOn: addMonths(_today, -11),
      coverUntil: addDays(_today, 22),
    ),
  ),
  Item(
    id: 'laptop',
    createdAt: _today,
    draft: ItemDraft(
      kind: ItemKind.bill,
      name: 'Laptop',
      source: 'Online order',
      amountMinor: 7499000,
      startsOn: addMonths(_today, -10),
      coverUntil: addDays(_today, 44),
    ),
  ),
]);

Finder _key(String key) => find.byKey(ValueKey(key));

Future<void> _tap(WidgetTester tester, String key) async {
  final target = _key(key);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _launch(
  WidgetTester tester,
  _Items items, {
  bool startAtHome = false,
  double scale = 1,
}) async {
  final actualSettings = _Settings();
  final today = Today(() => _today);
  final files = FileStore(Directory.systemTemp);
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = const Size(1179, 2556);
  tester.view.padding = const FakeViewPadding(top: 177, bottom: 102);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    items.dispose();
    actualSettings.dispose();
    today.dispose();
  });
  await tester.pumpWidget(
    PaperDrawerApp(
      initialLocation: startAtHome ? Routes.home : Routes.vault,
      deps: AppDependencies(
        items: items,
        legacyClaims: const _LegacyClaims(),
        settings: actualSettings,
        files: files,
        exporter: Exporter(files, today: today),
        recognizer: FakeTextRecognizer(const []),
        today: today,
        actions: const _Actions(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _Items extends ChangeNotifier implements ItemRepository {
  _Items(this.items);

  @override
  List<Item> items;
  @override
  List<Item> get active => items.where((item) => !item.isArchived).toList();
  @override
  List<Item> get archived => items.where((item) => item.isArchived).toList();
  @override
  int get activeCount => active.length;
  @override
  bool get atLimit => activeCount >= baseItemLimit;
  @override
  Item? byId(String id) => items.where((item) => item.id == id).firstOrNull;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LegacyClaims implements LegacyClaims {
  const _LegacyClaims();

  @override
  Future<LegacyClaimRows> read() async => LegacyClaimRows.empty;
  @override
  Future<void> eraseAll() async {}
}

class _Settings extends ChangeNotifier implements SettingsRepository {
  @override
  int get leadDays => 7;
  @override
  bool get remindersOn => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Actions extends DrawerActions {
  const _Actions();

  @override
  Future<String?> appVersion() async => '0.1.0';
}
