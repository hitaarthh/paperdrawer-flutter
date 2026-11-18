import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:paperdrawer/ui/core/theme/app_theme.dart';
import 'package:paperdrawer/ui/core/widgets/brand_bar.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child, double scale) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(top: 177, bottom: 102);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: pdTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(body: Column(children: [child])),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final scale in [1.0, 1.3]) {
    testWidgets('brand bar with action lays out at ${scale}x', (tester) async {
      var marks = 0;
      var actions = 0;
      await pump(
        tester,
        PdBrandBar(
          onMarkTap: () => marks++,
          trailing: PdBrandAction(
            key: const ValueKey('brand-action'),
            label: 'Scan or add',
            icon: LucideIcons.scanLine,
            onPressed: () => actions++,
          ),
        ),
        scale,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Paper Drawer'), findsOneWidget);

      // Sits below the status bar inset (177 / 3 = 59).
      final barTop = tester.getTopLeft(find.byType(PdBrandBar)).dy;
      final markTop = tester.getTopLeft(
        find.byKey(const ValueKey('brand-mark')),
      );
      expect(barTop, 0);
      expect(markTop.dy, greaterThanOrEqualTo(59));
      expect(
        tester.getSize(find.byKey(const ValueKey('brand-action'))).height,
        greaterThanOrEqualTo(44),
      );

      await tester.tap(find.byKey(const ValueKey('brand-mark')));
      await tester.tap(find.byKey(const ValueKey('brand-action')));
      expect(marks, 1);
      expect(actions, 1);
    });
  }

  testWidgets('brand bar without a mark tap is a header', (tester) async {
    await pump(tester, const PdBrandBar(), 1);
    expect(find.byKey(const ValueKey('brand-mark')), findsNothing);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Paper Drawer')),
      matchesSemantics(label: 'Paper Drawer', isHeader: true),
    );
  });

  testWidgets('disabled brand action ignores taps', (tester) async {
    await pump(
      tester,
      const PdBrandBar(
        trailing: PdBrandAction(
          key: ValueKey('brand-action'),
          label: 'Scan or add',
          onPressed: null,
        ),
      ),
      1,
    );
    await tester.tap(find.byKey(const ValueKey('brand-action')));
    expect(tester.takeException(), isNull);
  });
}
