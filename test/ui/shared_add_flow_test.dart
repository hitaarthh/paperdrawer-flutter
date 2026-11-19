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
}

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

Future<(_Session, _VaultService, _Capture)> _launch(WidgetTester tester) async {
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = const Size(1179, 2556);
  tester.view.padding = const FakeViewPadding(top: 177, bottom: 102);
  tester.platformDispatcher.textScaleFactorTestValue = 1.3;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final service = _VaultService();
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
  _VaultService() : super(_UnusedClient());

  final attempts = <String>[];
  bool rejectNext = false;
  PendingFile? original;
  ItemDraft? draft;

  @override
  Future<SharedVault> fetch(String userId) async =>
      const SharedVault(items: [], claims: []);

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
