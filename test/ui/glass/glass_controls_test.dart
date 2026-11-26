import 'dart:ui' show ImageFilter;

import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:paperdrawer/ui/core/glass/deadline_accessory.dart';
import 'package:paperdrawer/ui/core/glass/glass_scan_button.dart';
import 'package:paperdrawer/ui/core/glass/glass_toolbar_button.dart';
import 'package:paperdrawer/ui/core/glass/pd_glass.dart';
import 'package:paperdrawer/ui/core/theme/pd_colors.dart';

import '../theme/pd_harness.dart';

Widget _controls({
  VoidCallback? onScan,
  VoidCallback? onAccessory,
  VoidCallback? onBack,
  VoidCallback? onEdit,
}) => Scaffold(
  body: SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              GlassToolbarButton.icon(
                key: const ValueKey('back'),
                icon: const Icon(LucideIcons.chevronLeft),
                systemIcon: 'chevron.left',
                semanticLabel: 'Back',
                onPressed: onBack ?? () {},
              ),
              const Spacer(),
              GlassToolbarButton.label(
                key: const ValueKey('edit'),
                label: 'Edit',
                onPressed: onEdit ?? () {},
              ),
            ],
          ),
          const Spacer(),
          DeadlineAccessory(
            text: 'Boat earbuds · return closes Fri',
            count: '2 DAYS',
            semanticLabel:
                'Boat earbuds, return window closes Friday, 2 days left',
            onPressed: onAccessory ?? () {},
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: GlassScanButton(onPressed: onScan ?? () {}),
          ),
        ],
      ),
    ),
  ),
);

void main() {
  testWidgets('glass controls fit both themes and every text size', (
    tester,
  ) async {
    await forEachThemeAndScale(tester, (brightness, scale) async {
      await pumpPd(
        tester,
        _controls(),
        brightness: brightness,
        textScale: scale,
      );
    });
  });

  testWidgets('glass controls are reachable by VoiceOver with their labels', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var scans = 0;
    var opened = 0;
    await pumpPd(
      tester,
      _controls(onScan: () => scans++, onAccessory: () => opened++),
    );
    expect(find.bySemanticsLabel('Scan or add'), findsOneWidget);
    expect(find.bySemanticsLabel('Back'), findsOneWidget);
    expect(find.bySemanticsLabel('Edit'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Boat earbuds, return window closes Friday, 2 days left',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('scan-or-add')));
    await tester.tap(find.byKey(const ValueKey('deadline-accessory')));
    await tester.pumpAndSettle();
    expect(scans, 1);
    expect(opened, 1);
    semantics.dispose();
  });

  testWidgets('every glass control has at least a 44 pt hit area', (
    tester,
  ) async {
    await pumpPd(tester, _controls());
    for (final key in ['back', 'edit', 'scan-or-add', 'deadline-accessory']) {
      final size = tester.getSize(find.byKey(ValueKey(key)));
      expect(size.width, greaterThanOrEqualTo(44), reason: key);
      expect(size.height, greaterThanOrEqualTo(44), reason: key);
    }
  });

  testWidgets('fallback glass blurs what is behind it', (tester) async {
    await pumpPd(tester, _controls());
    expect(find.byType(BackdropFilter), findsWidgets);
    final filter = tester
        .widget<BackdropFilter>(find.byType(BackdropFilter).first)
        .filter;
    expect(filter, isA<ImageFilter>());
  });

  testWidgets('Reduce Transparency turns glass into solid surface-2', (
    tester,
  ) async {
    for (final brightness in Brightness.values) {
      await pumpPd(
        tester,
        _controls(),
        brightness: brightness,
        reduceTransparency: true,
      );
      expect(find.byType(BackdropFilter), findsNothing);
      final fills = tester
          .widgetList<ColoredBox>(
            find.descendant(
              of: find.byType(PdGlass),
              matching: find.byType(ColoredBox),
            ),
          )
          .map((box) => box.color)
          .toSet();
      final colors = PdColors.forBrightness(brightness);
      expect(fills, contains(colors.surface2));
      expect(fills, contains(colors.lime), reason: 'Scan stays lime');
      expect(fills.contains(colors.glassFill), isFalse);
    }
  });

  testWidgets('Increase Contrast adds a line border to glass', (tester) async {
    await pumpPd(tester, _controls(), highContrast: true);
    final glass = find.byType(PdGlass).first;
    final painters = tester
        .widgetList<CustomPaint>(
          find.descendant(of: glass, matching: find.byType(CustomPaint)),
        )
        .where((paint) => paint.foregroundPainter != null);
    expect(painters, isNotEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reduce Motion: a pressed control does not scale', (
    tester,
  ) async {
    await pumpPd(tester, _controls(), reduceMotion: true);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('scan-or-add'))),
    );
    await tester.pump(const Duration(milliseconds: 150));
    final scales = tester
        .widgetList<AnimatedScale>(
          find.descendant(
            of: find.byKey(const ValueKey('scan-or-add')),
            matching: find.byType(AnimatedScale),
          ),
        )
        .map((s) => s.scale);
    expect(scales, everyElement(1.0));
    await gesture.up();
  });

  testWidgets('without Reduce Motion a pressed control scales to 0.97', (
    tester,
  ) async {
    await pumpPd(tester, _controls());
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('scan-or-add'))),
    );
    await tester.pump(const Duration(milliseconds: 150));
    final scale = tester
        .widget<AnimatedScale>(
          find
              .descendant(
                of: find.byKey(const ValueKey('scan-or-add')),
                matching: find.byType(AnimatedScale),
              )
              .first,
        )
        .scale;
    expect(scale, 0.97);
    await gesture.up();
    await tester.pumpAndSettle();
  });
}
