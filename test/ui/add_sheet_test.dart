import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:paperdrawer/data/repositories/item_repository.dart';
import 'package:paperdrawer/data/services/capture_service.dart';
import 'package:paperdrawer/domain/item_status.dart';
import 'package:paperdrawer/domain/models/item.dart';
import 'package:paperdrawer/routing/router.dart';
import 'package:paperdrawer/ui/core/theme/app_theme.dart';
import 'package:paperdrawer/ui/features/add/add_details_args.dart';
import 'package:paperdrawer/ui/features/add/add_flow.dart';
import 'package:provider/provider.dart';

final _today = DateTime.utc(2026, 11, 18);

void main() {
  testWidgets('renders the design: usage, title, four kinds, three ways in', (
    tester,
  ) async {
    await _launch(tester, _Items.withCount(10));
    await _tap(tester, 'open-add');

    expect(find.text('SCAN OR ADD · 10 OF 25 ITEMS USED'), findsOneWidget);
    expect(find.text('What are you adding?'), findsOneWidget);
    for (final kind in ItemKind.values) {
      expect(_key('add-kind-${kind.name}'), findsOneWidget);
    }
    expect(find.text('BILL · PICKED'), findsOneWidget);
    expect(find.text('Bill & warranty'), findsOneWidget);
    expect(find.text('Insurance policy'), findsOneWidget);
    expect(find.text('Vehicle papers'), findsOneWidget);
    expect(find.text('Agreement'), findsOneWidget);
    expect(find.text('Take a photo'), findsOneWidget);
    expect(find.text('UPLOAD A FILE'), findsOneWidget);
    expect(find.text('TYPE IT IN'), findsOneWidget);
    // Everything fits above the home indicator without scrolling.
    final bottom = tester.getBottomLeft(_key('add-sheet-manual')).dy;
    expect(bottom, lessThan(852 - 34));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Take a photo opens the camera', (tester) async {
    await _launch(tester, _Items.withCount(0));
    await _tap(tester, 'open-add');
    await _tap(tester, 'add-sheet-camera');
    expect(find.text('camera stub'), findsOneWidget);
    expect(_key('add-sheet'), findsNothing);
  });

  testWidgets('Upload a file goes through Photos to reading', (tester) async {
    await _launch(tester, _Items.withCount(0));
    await _tap(tester, 'open-add');
    await _tap(tester, 'add-sheet-upload');
    expect(find.text('Choose a photo or PDF'), findsOneWidget);
    await tester.tap(find.text('Choose from Photos'));
    await tester.pumpAndSettle();
    expect(find.text('reading 2'), findsOneWidget);
  });

  testWidgets('Upload a file through Files, and a cancelled pick stays put', (
    tester,
  ) async {
    final capture = _Capture(files: const []);
    await _launch(tester, _Items.withCount(0), capture: capture);
    await _tap(tester, 'open-add');
    await _tap(tester, 'add-sheet-upload');
    await tester.tap(find.text('Browse Files'));
    await tester.pumpAndSettle();
    expect(capture.filesOpened, isTrue);
    expect(find.textContaining('reading'), findsNothing);
    expect(_key('open-add'), findsOneWidget);
  });

  testWidgets('Type it in carries the picked kind to the form', (tester) async {
    await _launch(tester, _Items.withCount(3));
    await _tap(tester, 'open-add');
    await _tap(tester, 'add-kind-policy');
    expect(find.text('POLICY · PICKED'), findsOneWidget);
    expect(find.text('BILL · PICKED'), findsNothing);
    expect(find.text('BILL'), findsOneWidget);
    await _tap(tester, 'add-sheet-manual');
    expect(find.text('details policy'), findsOneWidget);
  });

  testWidgets('dismissing the sheet goes nowhere', (tester) async {
    await _launch(tester, _Items.withCount(0));
    await _tap(tester, 'open-add');
    await tester.tapAt(const Offset(195, 60));
    await tester.pumpAndSettle();
    expect(_key('add-sheet'), findsNothing);
    expect(_key('open-add'), findsOneWidget);
  });

  testWidgets('a full Base drawer shows the limit notice instead', (
    tester,
  ) async {
    await _launch(tester, _Items.withCount(baseItemLimit));
    await _tap(tester, 'open-add');
    expect(_key('add-sheet'), findsNothing);
    expect(find.text('Your Base drawer is full'), findsOneWidget);
    await tester.tap(find.text('REVIEW OLD ITEMS'));
    await tester.pumpAndSettle();
    expect(find.text('review old'), findsOneWidget);
  });

  testWidgets('every option stays reachable at 130% text', (tester) async {
    await _launch(tester, _Items.withCount(24), scale: 1.3);
    await _tap(tester, 'open-add');
    await _tap(tester, 'add-kind-agreement');
    expect(find.text('AGREEMENT · PICKED'), findsOneWidget);
    for (final key in ['add-sheet-camera', 'add-sheet-upload']) {
      await tester.ensureVisible(_key(key));
      expect(_key(key).hitTestable(), findsOneWidget);
    }
    await _tap(tester, 'add-sheet-manual');
    expect(find.text('details agreement'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

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
  _Capture? capture,
  double scale = 1,
}) async {
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = const Size(1179, 2556);
  tester.view.padding = const FakeViewPadding(top: 177, bottom: 102);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  addTearDown(items.dispose);

  final router = GoRouter(
    initialLocation: Routes.vault,
    routes: [
      GoRoute(
        path: Routes.vault,
        builder: (context, state) => _Stub(
          state.uri.queryParameters['review'] == 'old' ? 'review old' : 'home',
          child: Builder(
            builder: (context) => TextButton(
              key: const ValueKey('open-add'),
              onPressed: () => AddFlow.start(context),
              child: const Text('Scan or add'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: Routes.camera,
        builder: (context, state) => const _Stub('camera stub'),
      ),
      GoRoute(
        path: Routes.reading,
        builder: (context, state) =>
            _Stub('reading ${(state.extra! as List<PendingFile>).length}'),
      ),
      GoRoute(
        path: Routes.details,
        builder: (context, state) =>
            _Stub('details ${(state.extra! as AddDetailsArgs).kind.name}'),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ItemRepository>.value(value: items),
        Provider<CaptureService>.value(value: capture ?? _Capture()),
      ],
      child: MaterialApp.router(
        theme: pdTheme(),
        themeMode: ThemeMode.dark,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _Stub extends StatelessWidget {
  const _Stub(this.label, {this.child});

  final String label;
  final Widget? child;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Column(children: [Text(label), ?child])),
  );
}

class _Items extends ChangeNotifier implements ItemRepository {
  _Items.withCount(int count)
    : items = [
        for (var i = 0; i < count; i++)
          Item(
            id: 'item-$i',
            createdAt: _today,
            draft: ItemDraft(kind: ItemKind.bill, name: 'Item $i'),
          ),
      ];

  @override
  final List<Item> items;
  @override
  List<Item> get active => items.where((item) => !item.isArchived).toList();
  @override
  int get activeCount => active.length;
  @override
  bool get atLimit => activeCount >= baseItemLimit;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Capture implements CaptureService {
  _Capture({
    this.files = const [
      PendingFile(path: '/tmp/a.jpg', name: 'a.jpg'),
      PendingFile(path: '/tmp/b.jpg', name: 'b.jpg'),
    ],
  });

  final List<PendingFile> files;
  var filesOpened = false;

  @override
  Future<List<PendingFile>> pickPhotos() async => files;

  @override
  Future<List<PendingFile>> pickFiles() async {
    filesOpened = true;
    return files;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
