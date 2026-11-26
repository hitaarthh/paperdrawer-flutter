import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:paperdrawer/ui/core/theme/pd_colors.dart';

/// `#RRGGBB` / `#RRGGBBAA` (CSS order) as a Flutter colour.
Color _css(String hex) {
  final h = hex.substring(1).toUpperCase();
  final rgb = h.substring(0, 6);
  final alpha = h.length == 8 ? h.substring(6) : 'FF';
  return Color(int.parse('$alpha$rgb', radix: 16));
}

void main() {
  test('every dark token in tokens.json has the same value in PdColors.dark', () {
    final json =
        jsonDecode(File('design/liquid-glass/tokens.json').readAsStringSync())
            as Map<String, Object?>;
    final color = json['color']! as Map<String, Object?>;
    final tokens = (color['tokens']! as List<Object?>)
        .cast<Map<String, Object?>>();
    final byName = PdColors.dark.byTokenName;
    final raw = {
      for (final token in tokens)
        token['name']! as String:
            (token['value']! as Map<String, Object?>)['dark']! as String,
    };
    for (final MapEntry(key: name, value: value) in raw.entries) {
      final resolved = value.startsWith('{')
          ? raw[value.substring(1, value.length - 1)]!
          : value;
      expect(byName[name], _css(resolved), reason: name);
    }
    // Every token has a field.
    expect(byName.keys.toSet().containsAll(raw.keys), isTrue);
  });

  test('light theme uses the canvas cream room and olive for lime text', () {
    const light = PdColors.light;
    expect(light.bg, const Color(0xFFF7F3DF));
    expect(light.limeText, const Color(0xFF465B16));
    expect(light.text, const Color(0xFF20241A));
    expect(light.focusRing, const Color(0xFF465B16));
    expect(PdColors.dark.limeText, PdColors.dark.lime);
  });

  test('paper, ink, lime fills and the orange fill are identical in both themes', () {
    const dark = PdColors.dark;
    const light = PdColors.light;
    for (final pick in <Color Function(PdColors)>[
      (c) => c.paper,
      (c) => c.paper2,
      (c) => c.paperRule,
      (c) => c.paperTrack,
      (c) => c.ink,
      (c) => c.ink2,
      (c) => c.inkMuted,
      (c) => c.dueInk,
      (c) => c.coveredInk,
      (c) => c.endedInk,
      (c) => c.lime,
      (c) => c.limePressed,
      (c) => c.onLime,
      (c) => c.glassLime,
      (c) => c.signalFill,
      (c) => c.focusRingPaper,
    ]) {
      expect(pick(light), pick(dark));
    }
  });

  test('light text pairs on the room keep at least 4.5:1 contrast', () {
    const light = PdColors.light;
    double contrast(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();
      final hi = la > lb ? la : lb;
      final lo = la > lb ? lb : la;
      return (hi + 0.05) / (lo + 0.05);
    }

    for (final ground in [light.bg, light.surface1, light.surface2]) {
      for (final ink in [
        light.text,
        light.text2,
        light.textMuted,
        light.textSubtle,
        light.limeText,
        light.signal,
        light.settled,
        light.danger,
      ]) {
        expect(contrast(ink, ground), greaterThanOrEqualTo(4.5));
      }
    }
  });

  test('forBrightness picks the matching palette', () {
    expect(PdColors.forBrightness(Brightness.dark), PdColors.dark);
    expect(PdColors.forBrightness(Brightness.light), PdColors.light);
  });

  test('lerp runs from dark at 0 to light at 1', () {
    expect(PdColors.dark.lerp(PdColors.light, 0), PdColors.dark);
    expect(PdColors.dark.lerp(PdColors.light, 1), PdColors.light);
    expect(PdColors.dark.lerp(null, 0.5), PdColors.dark);
    final mid = PdColors.dark.lerp(PdColors.light, 0.5);
    expect(mid.bg, Color.lerp(PdColors.dark.bg, PdColors.light.bg, 0.5));
    expect(mid.paper, PdColors.dark.paper);
  });

  test('copyWith replaces only the given tokens', () {
    final changed = PdColors.dark.copyWith(bg: const Color(0xFF000000));
    expect(changed.bg, const Color(0xFF000000));
    expect(changed.text, PdColors.dark.text);
    expect(changed == PdColors.dark, isFalse);
    expect(PdColors.dark.copyWith(), PdColors.dark);
  });
}
