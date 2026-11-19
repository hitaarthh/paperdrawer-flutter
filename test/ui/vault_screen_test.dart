import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:paperdrawer/app.dart';
import 'package:paperdrawer/data/repositories/claim_repository.dart';
import 'package:paperdrawer/data/repositories/item_repository.dart';
import 'package:paperdrawer/data/repositories/settings_repository.dart';
import 'package:paperdrawer/data/services/drawer_actions.dart';
import 'package:paperdrawer/data/services/exporter.dart';
import 'package:paperdrawer/data/services/file_store.dart';
import 'package:paperdrawer/data/services/text_recognizer.dart';
import 'package:paperdrawer/data/services/today.dart';
import 'package:paperdrawer/domain/formats.dart';
import 'package:paperdrawer/domain/item_status.dart';
import 'package:paperdrawer/domain/models/claim.dart';
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
        expect(find.text('The vault'), findsOneWidget);
        expect(find.text('Add the last thing you bought.'), findsOneWidget);
        expect(_key('scan-first-bill'), findsOneWidget);
        expect(_key('vault-search'), findsNothing);
        for (final kind in ['policy', 'vehicle', 'agreement']) {
          await tester.ensureVisible(_key('vault-start-$kind'));
          expect(_key('vault-start-$kind'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('start rows and Scan or add open the add sheet', (
      tester,
    ) async {
      await _launch(tester, _Items([]));

      await _tap(tester, 'vault-start-policy');
      expect(_key('add-sheet'), findsOneWidget);
      await tester.tapAt(const Offset(20, 120));
      await tester.pumpAndSettle();
      expect(_key('add-sheet'), findsNothing);

      expect(_key('vault-scan'), findsNothing);
      await _tap(tester, 'scan-or-add');
      expect(_key('add-sheet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('full vault', () {
    for (final scale in [1.0, 1.3]) {
      testWidgets('lays out every section at ${scale}x', (tester) async {
        await _launch(tester, _fullItems(), claims: _claims(), scale: scale);

        expect(
          find.text('005 ITEMS · 4 DUE SOON · 1 OPEN CLAIM'),
          findsNothing,
        );
        expect(find.text('The vault'), findsOneWidget);
        expect(_key('vault-search'), findsOneWidget);
        expect(find.text('5 OF 25'), findsOneWidget);
        expect(find.text('DUE NEXT'), findsNothing);
        expect(find.byType(VaultTicket), findsNothing);
        await tester.ensureVisible(_key('vault-filter-expired'));
        await tester.pumpAndSettle();
        expect(find.text('ENDED 0'), findsOneWidget);
        expect(find.text('SORTED BY WHAT’S DUE FIRST'), findsOneWidget);

        for (final id in ['earbuds', 'policy', 'puc', 'washer', 'laptop']) {
          await tester.ensureVisible(_key('vault-item-$id'));
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
        expect(find.text('Return by 20 Nov'), findsOneWidget);
        final verticalScroll = find
            .byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            )
            .first;
        for (final section in [
          'Original on file',
          'Coverage',
          'Claim kit',
          'FAN-230',
        ]) {
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
      'Home shows two deadline tickets and opens the Due soon filter',
      (tester) async {
        await _launch(
          tester,
          _fullItems(),
          claims: _claims(),
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

        await _tap(tester, 'home-more-due');
        expect(find.text('The vault'), findsOneWidget);
        expect(find.text('DUE SOON 4'), findsOneWidget);
        expect(_key('vault-item-laptop'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'a Home ticket opens its item, and an open claim opens its ledger',
      (tester) async {
        await _launch(
          tester,
          _fullItems(),
          claims: _claims(),
          startAtHome: true,
        );

        await _tap(tester, 'home-ticket-earbuds/returnWindow');
        expect(_key('item-claim'), findsOneWidget);
        await _tap(tester, 'back-button');
        expect(_key('coming-up-list'), findsOneWidget);

        await tester.scrollUntilVisible(
          _key('home-claim-claim-1').hitTestable(),
          180,
          scrollable: find.descendant(
            of: _key('coming-up-list'),
            matching: find.byType(Scrollable),
          ),
        );
        await _tap(tester, 'home-claim-claim-1');
        expect(find.text('Laptop repair claim'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('Home scrolls the last claim clear of the glass bar', (
      tester,
    ) async {
      final claims = _Claims([
        for (var i = 0; i < 6; i++)
          Claim(
            id: 'claim-$i',
            itemLabel: 'Item number $i with a longer name',
            type: ClaimType.repair,
            want: ClaimWant.repair,
            problem: 'The hinge cracked.',
            openedOn: addDays(_today, -i),
            stepSince: _today,
            step: 0,
            followUp: i == 0 ? DateTime(2026, 11, 21, 9) : null,
          ),
      ]);
      await _launch(
        tester,
        _fullItems(),
        claims: claims,
        startAtHome: true,
        scale: 1.3,
      );
      final scroll = find.descendant(
        of: _key('coming-up-list'),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        _key('home-claim-claim-0'),
        180,
        scrollable: scroll,
      );
      expect(find.text('FOLLOW UP SAT 21 NOV'), findsOneWidget);
      await tester.scrollUntilVisible(
        _key('home-claim-claim-5'),
        250,
        scrollable: scroll,
      );
      await tester.pumpAndSettle();
      expect(_key('home-claim-claim-5').hitTestable(), findsOneWidget);
      expect(_key('claims-tab'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('filter tabs and search narrow the list', (tester) async {
      await _launch(tester, _fullItems(), claims: _claims());

      await _tap(tester, 'vault-filter-inClaim');
      expect(_key('vault-item-laptop'), findsOneWidget);
      expect(_key('vault-item-earbuds'), findsNothing);
      await _tap(tester, 'vault-filter-expired');
      expect(find.text('Nothing has ended'), findsOneWidget);
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

_Claims _claims() => _Claims([
  Claim(
    id: 'claim-1',
    itemId: 'laptop',
    itemLabel: 'Laptop',
    type: ClaimType.repair,
    want: ClaimWant.repair,
    problem: 'The hinge cracked.',
    openedOn: addDays(_today, -14),
    stepSince: addDays(_today, -14),
    step: 0,
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
  _Claims? claims,
  bool startAtHome = false,
  double scale = 1,
}) async {
  final actualClaims = claims ?? _Claims([]);
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
    actualClaims.dispose();
    actualSettings.dispose();
    today.dispose();
  });
  await tester.pumpWidget(
    PaperDrawerApp(
      initialLocation: startAtHome ? Routes.home : Routes.vault,
      deps: AppDependencies(
        items: items,
        claims: actualClaims,
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

class _Claims extends ChangeNotifier implements ClaimRepository {
  _Claims(this.claims);

  @override
  final List<Claim> claims;
  @override
  bool hasOpenClaim(String itemId) => openFor(itemId) != null;
  @override
  Claim? openFor(String itemId) => claims
      .where((claim) => claim.itemId == itemId && claim.isOpen)
      .firstOrNull;
  @override
  Claim? byId(String id) => claims.where((claim) => claim.id == id).firstOrNull;
  @override
  int needsAction(DateTime today) => claims
      .where((claim) => claim.status(today) == ClaimStatus.escalate)
      .length;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
