import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:paperdrawer/app.dart';
import 'package:paperdrawer/data/repositories/item_repository.dart';
import 'package:paperdrawer/data/repositories/settings_repository.dart';
import 'package:paperdrawer/data/services/capture_service.dart';
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
import 'package:paperdrawer/ui/core/theme/tokens.dart';

final _today = DateTime.utc(2026, 11, 18);

void main() {
  testWidgets('the Settings dock opens and dismisses the file form at 130%', (
    tester,
  ) async {
    await _launch(tester, _Items([]), scale: 1.3);
    await _tap(tester, 'settings-tab');
    expect(_key('drawer-notifications'), findsNothing);
    await _tap(tester, 'scan-or-add');
    expect(find.text('Add a file'), findsOneWidget);
    expect(_key('scan-or-add'), findsNothing);
    expect(_key('drawer-notifications'), findsNothing);
    await _tap(tester, 'close-button');
    expect(find.text('Settings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('glass pages use a short live transition', (tester) async {
    await _launch(tester, _Items([]));
    await tester.tap(_key('drawer-notifications'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 125));

    final notifications = tester.element(find.text('Notifications'));
    final route = ModalRoute.of(notifications)!;
    expect(route.allowSnapshotting, isFalse);
    expect(route.transitionDuration, Pd.sheetDuration);
    expect(route.animation!.isAnimating, isTrue);

    await tester.pumpAndSettle();
    await _tap(tester, 'back-button');
    expect(find.text('Coming up'), findsOneWidget);
    expect(_key('drawer-notifications'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'item details cover a stationary drawer and scroll under actions',
    (tester) async {
      final items = _Items([
        Item(
          id: 'bill',
          createdAt: _today,
          draft: ItemDraft(
            kind: ItemKind.bill,
            name: 'Wireless earbuds',
            notes: List.filled(
              30,
              'A note about the original purchase.',
            ).join(' '),
          ),
        ),
      ]);
      await _launch(tester, items, scale: 1.3);
      await _tap(tester, 'vault-tab');
      final card = _key('vault-item-bill');
      final position = tester.getTopLeft(card);

      await tester.tap(card);
      await tester.pump();
      await tester.pump(Pd.sheetDuration ~/ 2);
      expect(tester.getTopLeft(card), position);
      await tester.pumpAndSettle();

      final back = _key('back-button');
      final edit = _key('item-edit');
      final backRect = tester.getRect(back);
      final editRect = tester.getRect(edit);
      final detailTitle = find.text('Wireless earbuds');
      expect(tester.getTopLeft(detailTitle).dy, greaterThan(backRect.bottom));
      final list = find.byType(ListView);
      tester
          .state<ScrollableState>(
            find.descendant(of: list, matching: find.byType(Scrollable)),
          )
          .position
          .jumpTo(Pd.tapMin);
      await tester.pumpAndSettle();
      expect(tester.getRect(back), backRect);
      expect(tester.getRect(edit), editRect);
      expect(tester.getTopLeft(detailTitle).dy, lessThan(backRect.bottom));

      final scrolledTitle = tester.getTopLeft(detailTitle);
      await _tap(tester, 'item-edit');
      expect(find.text('Edit item'), findsOneWidget);
      await _tap(tester, 'close-button');
      expect(tester.getTopLeft(detailTitle), scrolledTitle);

      await tester.tap(back);
      await tester.pump();
      await tester.pump(Pd.sheetDuration ~/ 2);
      expect(tester.getTopLeft(card), position);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(card), position);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('add, edit, open and delete an original from the drawer', (
    tester,
  ) async {
    final items = _Items([]);
    final actions = _FileActions();
    final capture = _FilesCapture();
    await _launch(tester, items, actions: actions, capture: capture);
    expect(find.text('Coming up'), findsOneWidget);
    await _tap(tester, 'drawer-notifications');
    expect(find.text('Notifications are off'), findsOneWidget);
    await _tap(tester, 'back-button');
    await _tap(tester, 'scan-or-add');

    await _tap(tester, 'save-to-drawer');
    expect(find.text('Choose a file to continue.'), findsOneWidget);
    await _tap(tester, 'choose-original');
    expect(capture.single, isTrue);
    await _tap(tester, 'item-kind-picker');
    for (final kind in ['Policy', 'Vehicle papers', 'Agreement']) {
      expect(find.text(kind), findsOneWidget);
    }
    await tester.tap(find.text('Agreement'));
    await tester.pumpAndSettle();
    await tester.enterText(_key('item-name'), 'Studio lease');
    await _tap(tester, 'save-to-drawer');

    expect(items.active.single.kind, ItemKind.agreement);
    expect(items.active.single.draft.coverageRenews, isFalse);
    expect(items.active.single.attachments.single.name, 'example.pdf');
    expect(find.text('Studio lease'), findsOneWidget);
    expect(_key('drawer-notifications'), findsNothing);
    await tester.tap(find.text('Open original'));
    await tester.pumpAndSettle();
    expect(actions.opened?.name, 'example.pdf');
    await _tap(tester, 'item-edit');
    await tester.enterText(_key('item-name'), 'Updated studio lease');
    await _tap(tester, 'save-to-drawer');
    expect(find.text('Updated studio lease'), findsOneWidget);
    expect(items.active.single.attachments, hasLength(1));
    await _tap(tester, 'item-delete');
    await tester.tap(find.text('Delete item'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.text('Item unavailable', skipOffstage: false), findsNothing);
    await tester.pumpAndSettle();
    expect(items.active, isEmpty);
    expect(_key('drawer-notifications'), findsOneWidget);
    expect(_key('drawer-add-first-file'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Home deadlines, Drawer filters and archive work at 130% text scale',
    (tester) async {
      final items = _Items([
        Item(
          id: 'due',
          createdAt: _today,
          draft: ItemDraft(
            kind: ItemKind.bill,
            name: 'Washing machine',
            source: 'Gupta Home Appliances',
            amountMinor: 2750000,
            startsOn: addMonths(_today, -12),
            coverUntil: addDays(_today, 6),
          ),
        ),
        Item(
          id: 'policy',
          createdAt: _today,
          draft: ItemDraft(
            kind: ItemKind.policy,
            name: 'Family health policy',
            coverUntil: addMonths(_today, 6),
          ),
        ),
        Item(
          id: 'archived',
          createdAt: _today,
          archivedAt: _today,
          draft: const ItemDraft(kind: ItemKind.vehicle, name: 'Activa PUC'),
        ),
      ]);
      await _launch(tester, items, scale: 1.3);

      expect(_key('home-ticket-due/warranty'), findsOneWidget);
      await _tap(tester, 'vault-tab');
      await tester.scrollUntilVisible(
        _key('vault-item-due'),
        200,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first,
      );
      expect(_key('vault-item-due'), findsOneWidget);
      await _tap(tester, 'vault-filter-due');
      expect(_key('vault-item-due'), findsOneWidget);
      expect(_key('vault-item-policy'), findsNothing);
      await _tap(tester, 'settings-tab');
      await _tap(tester, 'settings-data');
      await _tap(tester, 'settings-archive');
      expect(find.text('Activa PUC'), findsOneWidget);
      await _tap(tester, 'restore-item-archived');
      expect(items.byId('archived')!.isArchived, isFalse);
      expect(find.text('Nothing in the archive'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('saved claim links resolve to Home at 130% text', (tester) async {
    final claims = _LegacyClaims();
    await _launch(tester, _Items([]), legacyClaims: claims, scale: 1.3);
    final router = GoRouter.of(tester.element(find.text('Coming up')));
    for (final link in [
      '/claims',
      '/claims/laptop',
      '/claims/laptop/guidance',
      '/vault/item/laptop/claim',
    ]) {
      router.go(Routes.settings);
      await tester.pumpAndSettle();
      router.go(link);
      await tester.pumpAndSettle();
      expect(find.text('Coming up'), findsOneWidget);
      expect(find.textContaining('claim', findRichText: true), findsNothing);
    }
    expect(claims.erased, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('claim rows are erased only after Clear this drawer is confirmed', (
    tester,
  ) async {
    final claims = _LegacyClaims();
    await _launch(tester, _Items([]), legacyClaims: claims);
    await _tap(tester, 'settings-tab');
    await _tap(tester, 'settings-data');

    await _tap(tester, 'settings-clear');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(claims.erased, 0);

    await _tap(tester, 'settings-clear');
    await tester.tap(find.text('Clear drawer'));
    await tester.pumpAndSettle();
    expect(claims.erased, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('on-device Settings opens account, plan and data at 130%', (
    tester,
  ) async {
    await _launch(tester, _Items([]), scale: 1.3);
    await _tap(tester, 'settings-tab');
    expect(find.text('Settings'), findsOneWidget);
    expect(_key('drawer-notifications'), findsNothing);
    await _tap(tester, 'settings-account');
    expect(find.text('Account'), findsOneWidget);
    expect(find.text('On this iPhone'), findsOneWidget);
    await _tap(tester, 'back-button');
    await _tap(tester, 'settings-plan');
    expect(find.text('0 OF 25 ITEMS'), findsOneWidget);
    await _tap(tester, 'back-button');
    await _tap(tester, 'settings-data');
    expect(_key('settings-export'), findsOneWidget);
    expect(_key('settings-clear'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Finder _key(String key) => find.byKey(ValueKey(key));

Future<void> _tap(WidgetTester tester, String key) async {
  final target = _key(key);
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _launch(
  WidgetTester tester,
  _Items items, {
  _LegacyClaims? legacyClaims,
  DrawerActions actions = const _Actions(),
  CaptureService capture = const CaptureService(),
  double scale = 1,
}) async {
  final settings = _Settings();
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
    settings.dispose();
    today.dispose();
  });
  await tester.pumpWidget(
    PaperDrawerApp(
      deps: AppDependencies(
        items: items,
        legacyClaims: legacyClaims ?? _LegacyClaims(),
        settings: settings,
        files: files,
        exporter: Exporter(files, today: today),
        recognizer: FakeTextRecognizer(const []),
        today: today,
        actions: actions,
        capture: capture,
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
  Future<Item> create(
    ItemDraft draft, {
    List<PendingFile> files = const [],
  }) async {
    final item = Item(
      id: 'item-${items.length + 1}',
      draft: draft,
      createdAt: _today,
      attachments: [
        for (final file in files)
          Attachment(id: file.name, path: file.path, name: file.name, bytes: 1),
      ],
    );
    items.add(item);
    notifyListeners();
    return item;
  }

  @override
  Future<Item> update(
    String id,
    ItemDraft draft, {
    List<PendingFile> addFiles = const [],
    Set<String> removeAttachmentIds = const {},
    bool prependOriginal = false,
  }) async {
    final index = items.indexWhere((item) => item.id == id);
    final original = items[index];
    final saved = Item(
      id: id,
      draft: draft,
      createdAt: original.createdAt,
      attachments: original.attachments,
    );
    items[index] = saved;
    notifyListeners();
    return saved;
  }

  @override
  Future<void> delete(String id) async {
    items.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  @override
  Future<void> eraseAll() async {
    items.clear();
    notifyListeners();
  }

  @override
  Future<void> setArchived(String id, bool archived) async {
    final index = items.indexWhere((item) => item.id == id);
    final item = items[index];
    items[index] = Item(
      id: id,
      createdAt: item.createdAt,
      draft: item.draft,
      attachments: item.attachments,
      archivedAt: archived ? _today : null,
    );
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LegacyClaims implements LegacyClaims {
  int erased = 0;

  @override
  Future<LegacyClaimRows> read() async => LegacyClaimRows.empty;
  @override
  Future<void> eraseAll() async {
    erased++;
  }
}

class _Settings extends ChangeNotifier implements SettingsRepository {
  @override
  String? get profileName => null;
  @override
  bool get onBasePlan => true;
  @override
  List<int> get selectableLeadDays => SettingsRepository.leadDayChoices;
  @override
  String? get ticketDismissedKey => null;
  @override
  int get leadDays => 7;
  @override
  bool get remindersOn => false;
  @override
  Future<void> eraseAll() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Actions extends DrawerActions {
  const _Actions();

  @override
  Future<String?> appVersion() async => '0.1.0';
}

class _FilesCapture extends CaptureService {
  bool single = false;

  @override
  Future<List<PendingFile>> pickFiles({bool single = false}) async {
    this.single = single;
    return const [PendingFile(path: '/tmp/example.pdf', name: 'example.pdf')];
  }
}

class _FileActions extends _Actions {
  Attachment? opened;

  @override
  Future<void> openAttachment(Attachment attachment) async =>
      opened = attachment;
}
