import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:paperdrawer/app.dart';
import 'package:paperdrawer/data/repositories/item_repository.dart';
import 'package:paperdrawer/data/repositories/settings_repository.dart';
import 'package:paperdrawer/data/services/drawer_actions.dart';
import 'package:paperdrawer/data/services/exporter.dart';
import 'package:paperdrawer/data/services/file_store.dart';
import 'package:paperdrawer/data/services/legacy_claims.dart';
import 'package:paperdrawer/data/services/reminder_scheduler.dart';
import 'package:paperdrawer/data/services/text_recognizer.dart';
import 'package:paperdrawer/data/services/today.dart';
import 'package:paperdrawer/domain/bill_reader.dart';
import 'package:paperdrawer/domain/formats.dart';
import 'package:paperdrawer/domain/item_status.dart';
import 'package:paperdrawer/domain/models/item.dart';
import 'package:paperdrawer/routing/router.dart';
import 'package:paperdrawer/ui/features/add/add_details_args.dart';

final _today = DateTime.utc(2026, 11, 18);
const _headline = 'A nudge on your phone?';

void main() {
  testWidgets('first save with a warranty offers reminders; allow turns on', (
    tester,
  ) async {
    final app = await _launch(tester, grant: true);
    await _saveNew(tester, 'Mixer grinder');

    expect(find.text(_headline), findsOneWidget);
    expect(find.text('ONE LAST THING'), findsOneWidget);
    expect(find.textContaining('a week before'), findsOneWidget);
    // The sample is dated from Today: two days after 18 Nov 2026.
    expect(
      find.text('Wireless earbuds · return by Fri 20 Nov'),
      findsOneWidget,
    );
    expect(app.items.active.single.name, 'Mixer grinder');

    await _tap(tester, 'reminders-turn-on');
    expect(app.gateway.asked, 1);
    expect(app.settings.remindersOn, isTrue);
    expect(app.settings.remindersOffered, isTrue);
    expect(find.text(_headline), findsNothing);
    expect(find.text('Check the details'), findsNothing);
    expect(
      find.textContaining('Saved. Next reminder planned for'),
      findsOneWidget,
    );

    await _saveNew(tester, 'Ceiling fan');
    expect(app.items.active, hasLength(2));
    expect(find.text(_headline), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('declining at the iOS prompt shows a calm note, stays off', (
    tester,
  ) async {
    final app = await _launch(tester, grant: false);
    await _saveNew(tester, 'Mixer grinder');
    await _tap(tester, 'reminders-turn-on');

    expect(app.gateway.asked, 1);
    expect(app.settings.remindersOn, isFalse);
    expect(app.settings.remindersOffered, isTrue);
    expect(_key('reminders-message'), findsOneWidget);
    expect(find.textContaining('notifications stay off'), findsOneWidget);
    expect(_key('reminders-not-now'), findsNothing);

    await _tap(tester, 'reminders-done');
    expect(find.text(_headline), findsNothing);
    expect(find.text('Saved to your drawer'), findsOneWidget);

    await _saveNew(tester, 'Ceiling fan');
    expect(app.items.active, hasLength(2));
    expect(find.text(_headline), findsNothing);
    expect(app.gateway.asked, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('not now closes quietly and the offer never returns', (
    tester,
  ) async {
    final app = await _launch(tester, grant: true);
    await _saveNew(tester, 'Mixer grinder');
    await _tap(tester, 'reminders-not-now');

    expect(find.text(_headline), findsNothing);
    expect(app.gateway.asked, 0);
    expect(app.settings.remindersOn, isFalse);
    expect(app.settings.remindersOffered, isTrue);
    expect(find.text('Saved to your drawer'), findsOneWidget);

    await _saveNew(tester, 'Ceiling fan');
    expect(find.text(_headline), findsNothing);
    expect(app.items.active, hasLength(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('no offer for an item without a window to remind about', (
    tester,
  ) async {
    final app = await _launch(tester, grant: true);
    await _saveNew(tester, 'Rent agreement', withWarranty: false);
    expect(app.items.active, hasLength(1));
    expect(find.text(_headline), findsNothing);
    expect(app.settings.remindersOffered, isFalse);
    expect(find.text('Saved to your drawer'), findsOneWidget);
  });

  testWidgets('turning reminders on in Settings settles the offer too', (
    tester,
  ) async {
    final app = await _launch(tester, grant: true);
    await _tap(tester, 'settings-tab');
    await _tap(tester, 'settings-open-notifications');
    await _tap(tester, 'settings-reminders');
    expect(app.gateway.asked, 1);
    expect(app.settings.remindersOn, isTrue);
    expect(app.settings.remindersOffered, isTrue);

    await _saveNew(tester, 'Mixer grinder');
    expect(app.items.active, hasLength(1));
    expect(find.text(_headline), findsNothing);
  });

  testWidgets('the offer fits at 130% text scale', (tester) async {
    final app = await _launch(tester, grant: true, scale: 1.3);
    await _saveNew(tester, 'Mixer grinder');
    expect(find.text(_headline), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _tap(tester, 'reminders-turn-on');
    expect(app.settings.remindersOn, isTrue);
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

/// Opens "Check the details" for a new item and saves it.
Future<void> _saveNew(
  WidgetTester tester,
  String name, {
  bool withWarranty = true,
}) async {
  // An earlier "Saved · Undo" snackbar persists; swipe it away like a user.
  final context = rootNavigatorKey.currentContext!;
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  await tester.pumpAndSettle();
  GoRouter.of(context).push(
    Routes.details,
    extra: AddDetailsArgs(
      reading: withWarranty
          ? ScanReading(coverUntil: addMonths(_today, 12))
          : null,
      kind: withWarranty ? ItemKind.bill : ItemKind.agreement,
    ),
  );
  await tester.pumpAndSettle();
  await tester.enterText(_key('item-name'), name);
  await _tap(tester, 'save-to-drawer');
}

class _App {
  _App(this.items, this.settings, this.gateway);

  final _Items items;
  final _Settings settings;
  final _Gateway gateway;
}

Future<_App> _launch(
  WidgetTester tester, {
  required bool grant,
  double scale = 1,
}) async {
  final items = _Items();
  final settings = _Settings();
  final gateway = _Gateway(grant);
  final today = Today(() => _today);
  final files = FileStore(Directory.systemTemp);
  final reminders = ReminderScheduler(
    gateway: gateway,
    items: items,
    settings: settings,
    today: today,
  );
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
        legacyClaims: const _LegacyClaims(),
        settings: settings,
        files: files,
        exporter: Exporter(files, today: today),
        recognizer: FakeTextRecognizer(const []),
        today: today,
        actions: const _Actions(),
        reminders: reminders,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _App(items, settings, gateway);
}

class _Gateway implements NotificationGateway {
  _Gateway(this.grant);

  final bool grant;
  int asked = 0;

  @override
  Future<void> initialize(void Function(String) onTap) async {}
  @override
  Future<bool> requestPermission() async {
    asked++;
    return grant;
  }

  @override
  Future<void> cancelAll() async {}
  @override
  Future<void> schedule(PlannedReminder reminder) async {}
  @override
  Future<String?> launchLocation() async => null;
}

class _Items extends ChangeNotifier implements ItemRepository {
  @override
  final List<Item> items = [];
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
    );
    items.add(item);
    notifyListeners();
    return item;
  }

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
  String? get profileName => null;
  @override
  bool get onBasePlan => true;
  @override
  List<int> get selectableLeadDays => SettingsRepository.leadDayChoices;
  @override
  bool remindersOn = false;
  @override
  bool remindersOffered = false;
  @override
  String? get ticketDismissedKey => null;
  @override
  int get leadDays => 7;
  @override
  Future<void> setRemindersOn(bool value) async {
    remindersOn = value;
    notifyListeners();
  }

  @override
  Future<void> markRemindersOffered() async {
    remindersOffered = true;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Actions extends DrawerActions {
  const _Actions();

  @override
  Future<String?> appVersion() async => '0.1.0';
}
