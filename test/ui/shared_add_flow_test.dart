import 'dart:async';
import 'dart:typed_data';

import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoTextField;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:paperdrawer/data/services/capture_service.dart';
import 'package:paperdrawer/data/services/shared_account.dart';
import 'package:paperdrawer/data/services/shared_item_write.dart';
import 'package:paperdrawer/data/services/shared_vault_service.dart';
import 'package:paperdrawer/data/services/text_recognizer.dart';
import 'package:paperdrawer/data/services/today.dart';
import 'package:paperdrawer/domain/models/item.dart';
import 'package:paperdrawer/domain/models/shared_vault.dart';
import 'package:paperdrawer/routing/router.dart';
import 'package:paperdrawer/routing/shared_router.dart';
import 'package:paperdrawer/ui/core/theme/app_theme.dart';
import 'package:paperdrawer/ui/features/account/shared_session.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('shared Add captures and keeps the review available for retry', (
    tester,
  ) async {
    final (session, service, capture) = await _launch(tester);
    final router = GoRouter.of(tester.element(find.text('Coming up')));
    router.push(Routes.camera);
    await tester.pumpAndSettle();
    expect(capture.cameraOpens, 1);
    await _tap(tester, 'capture-shutter');
    await _tap(tester, 'capture-shutter');
    await _tap(tester, 'capture-done');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Check what we read'), findsOneWidget);
    expect(_text(tester, 'item-name'), 'Air cooler');
    service.rejectNext = true;
    await _tap(tester, 'save-to-drawer');
    expect(
      find.text('Your changes couldn’t be saved. Try again.'),
      findsOneWidget,
    );
    expect(_text(tester, 'item-name'), 'Air cooler');

    await _tap(tester, 'save-to-drawer');
    expect(service.attempts, hasLength(2));
    expect(service.attempts.toSet(), hasLength(1));
    expect(service.original?.name, 'capture-2.jpg');
    expect(service.draft?.reference, '4615-A');
    expect(service.draft?.startsOn, DateTime.utc(2025, 11, 6));
    expect(service.draft?.amountMinor, 7950);
    expect(find.text('ORIGINAL FILE'), findsOneWidget);
    expect(session.vault?.items.single.item.name, 'Air cooler');
    expect(session.webOpens, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shared Add uses Files and stays open after cancellation', (
    tester,
  ) async {
    final (session, service, capture) = await _launch(tester);
    capture.cancelFile = true;
    await _tap(tester, 'scan-or-add');
    await _tap(tester, 'choose-original');
    expect(capture.singleFile, isTrue);
    expect(find.text('Choose from Files'), findsOneWidget);
    capture.cancelFile = false;
    await _tap(tester, 'choose-original');
    expect(find.text('policy.pdf'), findsOneWidget);
    expect(service.attempts, isEmpty);
    expect(session.webOpens, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shared Add saves a manual document with the required end date', (
    tester,
  ) async {
    final (session, service, _) = await _launch(tester);
    await _tap(tester, 'scan-or-add');
    await _tap(tester, 'choose-original');
    await _tap(tester, 'item-kind-picker');
    await tester.tap(find.text('Agreement'));
    await tester.pumpAndSettle();
    expect(find.text('Add a file'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('item-name')),
      'Studio lease',
    );
    await _tap(tester, 'save-to-drawer');
    expect(
      find.text('Choose when this document ends or renews.'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('coverage-date')),
      250,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await _tap(tester, 'coverage-date');
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    await _tap(tester, 'save-to-drawer');

    expect(service.draft?.kind, ItemKind.agreement);
    expect(service.draft?.coverUntil, isNotNull);
    expect(service.original?.name, 'policy.pdf');
    expect(session.vault?.items.single.item.name, 'Studio lease');
    expect(session.webOpens, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'shared Edit opens in-app, prefills the bill, and keeps its file',
    (tester) async {
      final item = _savedItem(ItemKind.bill);
      final (session, service, _) = await _launch(tester, items: [item]);
      GoRouter.of(tester.element(find.text('Coming up')))
          .push(Routes.homeItem('saved'));
      await tester.pumpAndSettle();
      await _tap(tester, 'item-edit');
      expect(find.text('Edit item'), findsOneWidget);
      expect(_text(tester, 'item-name'), 'Saved bill');
      expect(find.text('original.pdf'), findsOneWidget);
      expect(find.text('15 Oct 2026'), findsOneWidget);
      expect(find.text('15 Oct 2027'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('item-name')),
        'Unsaved',
      );
      await _tap(tester, 'close-button');
      expect(service.attempts, isEmpty);
      expect(find.text('Saved bill'), findsOneWidget);

      await _tap(tester, 'item-edit');
      await tester.enterText(
        find.byKey(const ValueKey('item-name')),
        'Updated bill',
      );
      await _tap(tester, 'save-to-drawer');
      expect(find.text('Updated bill'), findsOneWidget);
      expect(service.attempts, ['saved']);
      expect(service.original, isNull);
      expect(session.vault!.items.single.originals, same(item.originals));
      expect(session.vault!.items.single.details, same(item.details));
      expect(session.webOpens, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('shared Edit retries a replacement on the same record', (
    tester,
  ) async {
    final (session, service, _) = await _launch(
      tester,
      items: [_savedItem(ItemKind.policy)],
    );
    GoRouter.of(tester.element(find.text('Coming up')))
        .push(Routes.item('saved'));
    await tester.pumpAndSettle();
    await _tap(tester, 'item-edit');
    expect(_text(tester, 'item-name'), 'Saved policy');
    expect(find.text('15 Oct 2027'), findsOneWidget);
    await _tap(tester, 'choose-original');
    await tester.tap(find.text('Keep current file'));
    await tester.pumpAndSettle();
    expect(find.text('original.pdf'), findsOneWidget);
    await _tap(tester, 'choose-original');
    await tester.enterText(
      find.byKey(const ValueKey('item-name')),
      'Updated policy',
    );
    service.rejectNext = true;
    await _tap(tester, 'save-to-drawer');
    expect(
      find.text('Your changes couldn’t be saved. Try again.'),
      findsOneWidget,
    );
    expect(find.text('policy.pdf'), findsOneWidget);
    expect(_text(tester, 'item-name'), 'Updated policy');
    expect(session.vault!.items.single.originals.single.name, 'original.pdf');
    await _tap(tester, 'save-to-drawer');
    expect(service.attempts, ['saved', 'saved']);
    expect(service.uploadIds.first, isNotNull);
    expect(service.uploadIds.toSet(), hasLength(1));
    expect(session.vault!.items.single.originals.single.name, 'policy.pdf');
    expect(find.text('Updated policy'), findsOneWidget);
    expect(session.webOpens, 0);
    expect(tester.takeException(), isNull);
  });
}

SharedItem _savedItem(ItemKind kind) => SharedItem(
  Item(
    id: 'saved',
    createdAt: DateTime.utc(2026, 10, 15),
    draft: ItemDraft(
      kind: kind,
      name: kind == ItemKind.bill ? 'Saved bill' : 'Saved policy',
      startsOn: DateTime.utc(2026, 10, 15),
      coverUntil: DateTime.utc(2027, 10, 15),
      currency: 'USD',
    ),
  ),
  const [
    SharedOriginal(
      name: 'original.pdf',
      path: 'owner/original.pdf',
      mime: 'application/pdf',
    ),
  ],
  const [('Other details', 'Existing details')],
  updatedAt: '2026-10-15T10:22:00Z',
);

String? _text(WidgetTester tester, String key) => tester
    .widget<CupertinoTextField>(find.byKey(ValueKey(key)))
    .controller
    ?.text;

Future<void> _tap(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<(_Session, _VaultService, _Capture)> _launch(
  WidgetTester tester, {
  List<SharedItem> items = const [],
}) async {
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = const Size(1179, 2556);
  tester.view.padding = const FakeViewPadding(top: 177, bottom: 102);
  tester.platformDispatcher.textScaleFactorTestValue = 1.3;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final service = _VaultService(items);
  final capture = _Capture();
  final session = _Session(_Account(), service, capture);
  final router = buildSharedRouter(session);
  addTearDown(router.dispose);
  addTearDown(session.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SharedSession>.value(value: session),
        Provider<CaptureService>.value(value: capture),
        ChangeNotifierProvider<Today>.value(value: session.today),
        Provider<TextRecognizer>.value(
          value: const FakeTextRecognizer([
            'MEGASTORE ELECTRONICS',
            'INV 4615-A',
            'Invoice Date: 06 Nov 2025',
            'Product: Air cooler',
            r'TOTAL $79.50',
          ]),
        ),
      ],
      child: MaterialApp.router(theme: pdTheme(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return (session, service, capture);
}

class _Session extends SharedSession {
  _Session(super.account, SharedVaultService service, CaptureService capture)
    : super(service: service, capture: capture);

  int webOpens = 0;

  @override
  Future<void> openWeb(String path) async => webOpens++;
}

class _VaultService extends SharedVaultService {
  _VaultService(this.items) : super(_UnusedClient());

  final List<SharedItem> items;
  final attempts = <String>[];
  final uploadIds = <String?>[];
  bool rejectNext = false;
  PendingFile? original;
  ItemDraft? draft;

  @override
  Future<SharedVault> fetch(String userId) async =>
      SharedVault(items: items, claims: const []);

  @override
  Future<SharedItem> updateItem(
    String userId,
    SharedItem item,
    ItemDraft draft, {
    PendingFile? original,
    String? uploadId,
  }) async {
    attempts.add(item.item.id);
    uploadIds.add(uploadId);
    if (rejectNext) {
      rejectNext = false;
      throw StateError('Connection interrupted');
    }
    this.original = original;
    return SharedItem(
      Item(id: item.item.id, createdAt: item.item.createdAt, draft: draft),
      original == null
          ? item.originals
          : [
              SharedOriginal(
                name: original.name,
                path: 'owner/${original.name}',
                mime: 'application/pdf',
              ),
            ],
      item.details,
    );
  }

  @override
  Future<SharedItem> createItem(
    String userId,
    String id,
    ItemDraft draft, {
    PendingFile? original,
  }) async {
    SharedItemWrite.arguments(id, draft);
    attempts.add(id);
    if (rejectNext) {
      rejectNext = false;
      throw StateError('Connection interrupted');
    }
    this.original = original;
    this.draft = draft;
    return SharedItem(Item(id: id, createdAt: DateTime(2025), draft: draft), [
      if (original != null)
        SharedOriginal(
          name: original.name,
          path: 'owner/${original.name}',
          mime: 'image/jpeg',
        ),
    ], []);
  }

  @override
  Future<Uint8List> fetchOriginal(
    String userId,
    SharedOriginal original,
  ) async => Uint8List(0);

  @override
  Future<void> clearDownloads(String userId) async {}
}

class _Account extends SharedAccount {
  _Account()
    : super(
        _UnusedClient(),
        SharedAccountConfig(
          Uri.parse('https://example.invalid'),
          'unused',
          Uri.parse('https://example.invalid'),
        ),
      );

  @override
  Stream<AuthState> get changes => const Stream.empty();

  @override
  User get user => const User(
    id: 'owner',
    appMetadata: {},
    userMetadata: {},
    aud: '',
    createdAt: '',
  );
}

class _UnusedClient implements SupabaseClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Capture extends CaptureService {
  int cameraOpens = 0;
  bool singleFile = false;
  bool cancelFile = false;

  @override
  Future<CaptureSession> openCamera() async {
    cameraOpens++;
    return _Camera();
  }

  @override
  Future<CaptureOriginal> inspect(PendingFile original) async =>
      const CaptureOriginal(size: 2048);

  @override
  Future<List<PendingFile>> pickFiles({bool single = false}) async {
    singleFile = single;
    return cancelFile
        ? const []
        : const [PendingFile(path: '/tmp/policy.pdf', name: 'policy.pdf')];
  }
}

class _Camera implements CaptureSession {
  int _photos = 0;

  @override
  Widget buildPreview() => const ColoredBox(color: Colors.black);

  @override
  Future<PendingFile> takePicture() async {
    final name = 'capture-${++_photos}.jpg';
    return PendingFile(path: '/tmp/$name', name: name);
  }

  @override
  Future<void> setTorch(bool enabled) async {}

  @override
  Future<void> close() async {}
}
