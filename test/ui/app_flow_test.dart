import 'dart:io';

import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:paperdrawer/app.dart';
import 'package:paperdrawer/data/repositories/claim_repository.dart';
import 'package:paperdrawer/data/repositories/item_repository.dart';
import 'package:paperdrawer/data/repositories/settings_repository.dart';
import 'package:paperdrawer/data/services/capture_service.dart';
import 'package:paperdrawer/data/services/drawer_actions.dart';
import 'package:paperdrawer/data/services/exporter.dart';
import 'package:paperdrawer/data/services/file_store.dart';
import 'package:paperdrawer/data/services/text_recognizer.dart';
import 'package:paperdrawer/data/services/today.dart';
import 'package:paperdrawer/domain/formats.dart';
import 'package:paperdrawer/domain/item_status.dart';
import 'package:paperdrawer/domain/models/claim.dart';
import 'package:paperdrawer/domain/models/item.dart';
import 'package:paperdrawer/ui/core/widgets/stamp.dart';
import 'package:paperdrawer/ui/features/claims/claim_detail_screen.dart';

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
    await tester.pumpAndSettle();
    expect(items.active, isEmpty);
    expect(_key('drawer-notifications'), findsOneWidget);
    expect(_key('drawer-add-first-file'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Home deadlines, Vault filters, ledgers and archive work at 130% text scale',
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
      final claims = _Claims([
        Claim(
          id: 'claim-1',
          itemId: 'policy',
          itemLabel: 'Family health policy',
          type: ClaimType.insurance,
          want: ClaimWant.payout,
          problem: 'I submitted my documents and am waiting for a reply.',
          openedOn: addDays(_today, -17),
          stepSince: addDays(_today, -17),
          step: 0,
        ),
      ]);
      await _launch(tester, items, claims: claims, scale: 1.3);

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
      await _tap(tester, 'home-tab');
      await _scrollHome(tester, 'home-claim-claim-1');
      await _tap(tester, 'home-claim-claim-1');
      expect(find.text('Family health policy insurance claim'), findsOneWidget);
      expect(find.widgetWithText(PdStamp, 'OPEN'), findsOneWidget);
      expect(find.text('Time to go one step up'), findsNothing);
      await _tap(tester, 'back-button');
      await _tap(tester, 'settings-tab');
      await tester.scrollUntilVisible(
        _key('settings-archive').hitTestable(),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await _tap(tester, 'settings-archive');
      expect(find.text('Activa PUC'), findsOneWidget);
      await _tap(tester, 'restore-item-archived');
      expect(items.byId('archived')!.isArchived, isFalse);
      expect(find.text('Nothing in the archive'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'legacy claim guidance can still open a draft and record a sent message',
    (tester) async {
      final opened = addDays(_today, -14);
      final claims = _Claims([
        Claim(
          id: 'laptop',
          itemLabel: 'Laptop',
          type: ClaimType.repair,
          want: ClaimWant.repair,
          problem: 'The hinge is loose.',
          reference: 'SR-55821',
          openedOn: opened,
          stepSince: opened,
          step: 0,
          events: [
            ClaimEvent(
              id: 'opened',
              on: opened,
              kind: ClaimEventKind.opened,
              text: 'Claim opened',
            ),
          ],
        ),
      ]);
      final actions = _ClaimActions();
      await _launch(
        tester,
        _Items([]),
        claims: claims,
        actions: actions,
        scale: 1.3,
      );
      await _tap(tester, 'home-claim-laptop');
      await _tap(tester, 'claim-actions');
      await tester.tap(find.text('Claim guidance'));
      await tester.pumpAndSettle();
      final backLabel = find.descendant(
        of: _key('back-button'),
        matching: find.text('CLAIMS'),
      );
      expect(
        tester.renderObject<RenderParagraph>(backLabel).didExceedMaxLines,
        isFalse,
      );
      expect(
        find.text('WARRANTY REPAIR · LAPTOP · OPENED 4 NOV 2026'),
        findsOneWidget,
      );
      expect(find.text('Time to go one step up'), findsOneWidget);
      final scroll = find
          .descendant(
            of: find.byType(ClaimDetailScreen),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            ),
          )
          .first;

      await tester.scrollUntilVisible(
        _key('open-claim-mail'),
        200,
        scrollable: scroll,
      );
      await _tap(tester, 'open-claim-mail');
      expect(actions.opened?.scheme, 'mailto');
      expect(actions.opened?.queryParameters['body'], contains('SR-55821'));
      expect(claims.lastSent, isNull);

      await _tap(tester, 'copy-claim-message');
      expect(actions.copied, startsWith('To: Grievance officer'));
      await _tap(tester, 'claim-log-sent');
      expect(claims.lastSent, ('laptop', 1));

      await tester.scrollUntilVisible(
        _key('claim-log-update'),
        220,
        scrollable: scroll,
      );
      expect(find.text('RECOMMENDED NEXT'), findsOneWidget);
      expect(find.text('Claim opened'), findsOneWidget);
      await _tap(tester, 'claim-log-update');
      await tester.tap(find.text('Add a note'));
      await tester.pumpAndSettle();
      await tester.enterText(
        _key('claim-log-text'),
        'Asked for a repair date.',
      );
      await tester.pump();
      await _tap(tester, 'save-claim-log');
      expect(claims.lastNote, ('laptop', 'Asked for a repair date.'));

      await _tap(tester, 'mark-claim-settled');
      expect(find.text('HOW WAS IT RESOLVED?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('settled claims remain available from Home at 130% text scale', (
    tester,
  ) async {
    Claim claim(String id, String name, int age, {int? settledDaysAgo}) {
      final opened = addDays(_today, -age);
      return Claim(
        id: id,
        itemLabel: name,
        type: ClaimType.repair,
        want: ClaimWant.repair,
        problem: 'It stopped working.',
        openedOn: opened,
        stepSince: opened,
        step: 0,
        settledOn: settledDaysAgo == null
            ? null
            : addDays(_today, -settledDaysAgo),
      );
    }

    final claims = _Claims([
      claim('waiting', 'Mixer', 4),
      claim('settled', 'Headphones', 12, settledDaysAgo: 2),
      claim('late', 'Laptop with a loose hinge', 14),
    ]);
    await _launch(tester, _Items([]), claims: claims, scale: 1.3);
    expect(_key('claims-tab'), findsNothing);
    expect(_key('home-claim-settled'), findsNothing);
    await _scrollHome(tester, 'home-claim-history');
    await _tap(tester, 'home-claim-history');
    expect(find.text('Claim history'), findsOneWidget);
    await tester.scrollUntilVisible(
      _key('home-claim-settled'),
      180,
      scrollable: find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .first,
    );
    expect(find.text('SETTLED MON 16 NOV'), findsOneWidget);
    await _tap(tester, 'back-button');
    await _tap(tester, 'scan-or-add');
    expect(find.text('Add a file'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _scrollHome(WidgetTester tester, String target) async {
  await tester.scrollUntilVisible(
    _key(target).hitTestable(),
    180,
    scrollable: find.descendant(
      of: _key('coming-up-list'),
      matching: find.byType(Scrollable),
    ),
  );
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
  _Claims? claims,
  DrawerActions actions = const _Actions(),
  CaptureService capture = const CaptureService(),
  double scale = 1,
}) async {
  final actualClaims = claims ?? _Claims([]);
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
    actualClaims.dispose();
    settings.dispose();
    today.dispose();
  });
  await tester.pumpWidget(
    PaperDrawerApp(
      deps: AppDependencies(
        items: items,
        claims: actualClaims,
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

class _Claims extends ChangeNotifier implements ClaimRepository {
  _Claims(this.claims);

  (String, int?)? lastSent;
  (String, String)? lastNote;

  @override
  Future<Claim> openLedger(Item item, DateTime today) async {
    final claim = Claim(
      id: 'new-claim',
      itemId: item.id,
      itemLabel: item.name,
      type: ClaimType.repair,
      want: ClaimWant.repair,
      problem: '',
      openedOn: today,
      step: 0,
      stepSince: today,
      nudgeDays: 0,
      events: [
        ClaimEvent(
          id: 'opening',
          on: today,
          kind: ClaimEventKind.opened,
          text: 'Claim opened',
        ),
      ],
    );
    claims.add(claim);
    notifyListeners();
    return claim;
  }

  @override
  Future<void> load() async {}

  @override
  Future<void> logSent(String id, DateTime today, {int? step}) async {
    lastSent = (id, step);
  }

  @override
  Future<void> addNote(String id, DateTime today, String text) async {
    lastNote = (id, text);
  }

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
  String? get ticketDismissedKey => null;
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

class _ClaimActions extends _Actions {
  Uri? opened;
  String? copied;

  @override
  Future<void> openLink(Uri url) async {
    opened = url;
  }

  @override
  Future<void> copyText(String text) async {
    copied = text;
  }
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
