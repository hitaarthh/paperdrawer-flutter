import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:paperdrawer/ui/core/theme/pd_colors.dart';
import 'package:paperdrawer/ui/core/theme/pd_dynamic_type.dart';
import 'package:paperdrawer/ui/core/theme/pd_theme.dart';
import 'package:paperdrawer/ui/core/theme/pd_type_scale.dart';

import 'pd_harness.dart';

void main() {
  test('both themes carry their palette and the type scale', () {
    for (final brightness in Brightness.values) {
      final theme = pdThemeData(brightness);
      expect(theme.brightness, brightness);
      expect(
        theme.extension<PdColors>(),
        PdColors.forBrightness(brightness),
      );
      expect(theme.extension<PdTypeScale>(), PdTypeScale.standard);
      expect(
        theme.scaffoldBackgroundColor,
        PdColors.forBrightness(brightness).bg,
      );
      expect(
        pdCupertinoThemeData(brightness).primaryColor,
        PdColors.forBrightness(brightness).limeText,
      );
    }
  });

  test('type uses the pubspec families and the token sizes', () {
    const t = 'Bricolage';
    final type = PdTypeScale.standard;
    expect(type.largeTitle.fontFamily, t);
    expect(type.largeTitle.fontSize, 34);
    expect(type.figure.fontSize, 40);
    expect(type.body.fontFamily, 'Inter');
    expect(type.body.fontSize, 17);
    expect(type.label.fontFamily, 'JetBrainsMono');
    expect(type.label.letterSpacing, closeTo(11 * 0.08, 0.001));
    expect(type.status.fontWeight, FontWeight.w600);
    expect(type.body.color, isNull, reason: 'colour comes from the layer');
  });

  testWidgets('context.pd follows the theme brightness', (tester) async {
    for (final brightness in Brightness.values) {
      late PdThemeView seen;
      await pumpPd(
        tester,
        Builder(
          builder: (context) {
            seen = context.pd;
            return const SizedBox.shrink();
          },
        ),
        brightness: brightness,
      );
      expect(seen.colors, PdColors.forBrightness(brightness));
      expect(seen.type, PdTypeScale.standard);
    }
  });

  testWidgets('PdDarkTheme keeps Camera dark inside a light app', (
    tester,
  ) async {
    late PdColors seen;
    await pumpPd(
      tester,
      PdDarkTheme(
        child: Builder(
          builder: (context) {
            seen = context.pd.colors;
            return const SizedBox.shrink();
          },
        ),
      ),
      brightness: Brightness.light,
    );
    expect(seen, PdColors.dark);
  });

  testWidgets('accessibility sizes start at AX1', (tester) async {
    final results = <double, bool>{};
    for (final scale in [1.0, 1.3, 1.7, PdDynamicType.largestScale]) {
      await pumpPd(
        tester,
        Builder(
          builder: (context) {
            results[scale] = PdDynamicType.isAccessibilitySize(context);
            return const SizedBox.shrink();
          },
        ),
        textScale: scale,
      );
    }
    expect(results, {
      1.0: false,
      1.3: false,
      1.7: true,
      PdDynamicType.largestScale: true,
    });
  });
}
