import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:paperdrawer/ui/core/glass/deadline_accessory.dart';
import 'package:paperdrawer/ui/core/glass/pd_destination.dart';
import 'package:paperdrawer/ui/core/glass/pd_toast.dart';
import 'package:paperdrawer/ui/core/layout/pd_adaptive_scaffold.dart';
import 'package:paperdrawer/ui/core/layout/pd_sidebar.dart';
import 'package:paperdrawer/ui/core/widgets/icons.dart';

import '../theme/pd_harness.dart';

const _destinations = [
  PdDestination(
    id: 'home',
    label: 'Home',
    glyph: PdGlyph.home,
    systemIcon: 'house',
  ),
  PdDestination(
    id: 'vault',
    label: 'Vault',
    glyph: PdGlyph.vault,
    systemIcon: 'archivebox',
    count: 10,
  ),
  PdDestination(
    id: 'settings',
    label: 'Settings',
    glyph: PdGlyph.settings,
    systemIcon: 'slider.horizontal.3',
  ),
];

final class _Log {
  final selected = <int>[];
  final filters = <String>[];
  int scans = 0;
  int deadlines = 0;
  double? bodyBottomPadding;
}

Widget _shell(
  _Log log, {
  int selectedIndex = 1,
  bool accessory = true,
  PdToastController? toasts,
  bool showDock = true,
}) => PdAdaptiveScaffold(
  destinations: _destinations,
  selectedIndex: selectedIndex,
  onDestinationSelected: log.selected.add,
  onScan: () => log.scans++,
  toasts: toasts,
  showDock: showDock,
  accessory: accessory
      ? DeadlineAccessory(
          text: 'Boat earbuds · return closes Fri',
          count: '2 DAYS',
          semanticLabel:
              'Boat earbuds, return window closes Friday, 2 days left',
          onPressed: () => log.deadlines++,
        )
      : null,
  sidebarFilters: PdSidebarFilters(
    title: 'VAULT',
    selectedId: 'due-soon',
    onSelected: (filter) => log.filters.add(filter.id),
    filters: const [
      PdSidebarFilter(id: 'due-soon', label: 'DUE SOON', count: 4, due: true),
      PdSidebarFilter(id: 'covered', label: 'COVERED', count: 5),
      PdSidebarFilter(id: 'ended', label: 'ENDED', count: 1),
    ],
  ),
  body: Builder(
    builder: (context) {
      log.bodyBottomPadding = MediaQuery.paddingOf(context).bottom;
      return ListView(
        key: const ValueKey('body-list'),
        padding: EdgeInsets.only(
          top: MediaQuery.paddingOf(context).top,
          bottom: MediaQuery.paddingOf(context).bottom + 48,
        ),
        children: [
          for (var i = 0; i < 40; i++)
            SizedBox(height: 60, child: Text('Row $i')),
        ],
      );
    },
  ),
);

void main() {
  testWidgets('compact: tab bar, Scan and accessory fit both themes and every text size', (
    tester,
  ) async {
    await forEachThemeAndScale(tester, (brightness, scale) async {
      await pumpPd(
        tester,
        _shell(_Log()),
        brightness: brightness,
        textScale: scale,
      );
      for (final key in ['home-tab', 'vault-tab', 'settings-tab']) {
        expect(find.byKey(ValueKey(key)), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('scan-or-add')), findsOneWidget);
      expect(find.byKey(const ValueKey('deadline-accessory')), findsOneWidget);
      expect(find.byKey(const ValueKey('sidebar')), findsNothing);
    });
  });

  testWidgets('regular: the sidebar replaces the tab bar in both themes and every text size', (
    tester,
  ) async {
    await forEachThemeAndScale(tester, (brightness, scale) async {
      await pumpPd(
        tester,
        _shell(_Log()),
        brightness: brightness,
        textScale: scale,
        device: PdTestDevice.iPad,
      );
      expect(find.byKey(const ValueKey('sidebar')), findsOneWidget);
      expect(find.byKey(const ValueKey('vault-tab')), findsNothing);
      expect(find.byKey(const ValueKey('scan-or-add')), findsOneWidget);
    });
  });

  testWidgets('compact: tapping tabs, Scan and the accessory calls back', (
    tester,
  ) async {
    final log = _Log();
    await pumpPd(tester, _shell(log));
    await tester.tap(find.byKey(const ValueKey('settings-tab')));
    await tester.tap(find.byKey(const ValueKey('scan-or-add')));
    await tester.tap(find.byKey(const ValueKey('deadline-accessory')));
    await tester.pumpAndSettle();
    expect(log.selected, [2]);
    expect(log.scans, 1);
    expect(log.deadlines, 1);
  });

  testWidgets('compact: VoiceOver reads tabs with position and selection', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpPd(tester, _shell(_Log()));
    expect(
      tester.getSemantics(find.byKey(const ValueKey('vault-tab'))),
      containsSemantics(
        label: 'Vault',
        hint: 'Tab 2 of 3',
        isSelected: true,
        isButton: true,
      ),
    );
    expect(
      tester.getSemantics(find.byKey(const ValueKey('home-tab'))),
      containsSemantics(label: 'Home', hint: 'Tab 1 of 3', isSelected: false),
    );
    expect(find.bySemanticsLabel('Scan or add'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('regular: sidebar destinations, filters and Scan or add call back', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final log = _Log();
    await pumpPd(tester, _shell(log), device: PdTestDevice.iPad);
    expect(find.bySemanticsLabel('Vault, 10'), findsOneWidget);
    expect(find.bySemanticsLabel('DUE SOON, 4'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sidebar-home')));
    await tester.tap(find.byKey(const ValueKey('sidebar-filter-covered')));
    await tester.tap(find.byKey(const ValueKey('scan-or-add')));
    await tester.pumpAndSettle();
    expect(log.selected, [0]);
    expect(log.filters, ['covered']);
    expect(log.scans, 1);
    final sidebar = tester.getRect(find.byKey(const ValueKey('sidebar')));
    expect(sidebar.width, 320);
    expect(sidebar.left, 12);
    semantics.dispose();
  });

  testWidgets('compact: the body is told how much the dock covers', (
    tester,
  ) async {
    final withAccessory = _Log();
    await pumpPd(tester, _shell(withAccessory));
    // iPhone 16 home indicator 34 pt + 8 + 62 + 44 + 8.
    expect(withAccessory.bodyBottomPadding, 34 + 8 + 62 + 44 + 8);
    final without = _Log();
    await pumpPd(tester, _shell(without, accessory: false));
    expect(without.bodyBottomPadding, 34 + 8 + 62);
  });

  testWidgets('compact: the dock hides while the keyboard is up', (
    tester,
  ) async {
    pdSetDevice(tester, PdTestDevice.iPhone16);
    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    await pumpPd(tester, _shell(_Log()));
    expect(find.byKey(const ValueKey('glass-dock')), findsNothing);
  });

  testWidgets('compact: scrolling down minimises the bar and up restores it', (
    tester,
  ) async {
    await pumpPd(tester, _shell(_Log()));
    await tester.drag(
      find.byKey(const ValueKey('body-list')),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('glass-dock-min')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-tab')), findsNothing);
    expect(find.byKey(const ValueKey('deadline-accessory')), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('body-list')),
      const Offset(0, 200),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-tab')), findsOneWidget);
  });

  testWidgets('a toast takes the accessory’s place, then gives it back', (
    tester,
  ) async {
    final toasts = PdToastController(haptics: false);
    addTearDown(toasts.dispose);
    await pumpPd(tester, _shell(_Log(), toasts: toasts));
    toasts.show(const PdToastMessage('Saved. First reminder on 17 Nov.'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('toast')), findsOneWidget);
    expect(find.byKey(const ValueKey('deadline-accessory')), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('toast')), findsNothing);
    expect(find.byKey(const ValueKey('deadline-accessory')), findsOneWidget);
  });

  testWidgets('Reduce Transparency keeps the shell working', (tester) async {
    for (final device in PdTestDevice.values) {
      await pumpPd(
        tester,
        _shell(_Log()),
        device: device,
        reduceTransparency: true,
        reduceMotion: true,
        highContrast: true,
      );
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byKey(const ValueKey('scan-or-add')), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
