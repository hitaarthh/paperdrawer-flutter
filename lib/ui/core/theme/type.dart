import 'dart:ui' show FontVariation;

import 'package:flutter/widgets.dart';

import 'tokens.dart';

/// Type scale from tokens.json. The bundled fonts are variable, so weight is
/// set on the `wght` axis as well as [FontWeight] (and `opsz` for Bricolage).
/// Sizes scale with Dynamic Type through the app's [TextScaler].
abstract final class PdType {
  static const display = 'Bricolage';
  static const sans = 'Inter';
  static const mono = 'JetBrainsMono';

  static TextStyle _display(double size, double lh, int weight, double em) =>
      TextStyle(
        fontFamily: display,
        fontSize: size,
        height: lh / size,
        fontWeight: FontWeight.values[(weight ~/ 100) - 1],
        fontVariations: [
          FontVariation.weight(weight.toDouble()),
          FontVariation.opticalSize(size.clamp(12, 96).toDouble()),
        ],
        letterSpacing: size * em,
        color: Pd.text,
      );

  static TextStyle _sans(double size, double lh, int weight) => TextStyle(
    fontFamily: sans,
    fontSize: size,
    height: lh / size,
    fontWeight: FontWeight.values[(weight ~/ 100) - 1],
    fontVariations: [FontVariation.weight(weight.toDouble())],
    color: Pd.text,
  );

  static TextStyle _mono(double size, double lh, int weight, double em) =>
      TextStyle(
        fontFamily: mono,
        fontSize: size,
        height: lh / size,
        fontWeight: FontWeight.values[(weight ~/ 100) - 1],
        fontVariations: [FontVariation.weight(weight.toDouble())],
        letterSpacing: size * em,
        color: Pd.text,
      );

  // Display (Bricolage Grotesque)
  static final largeTitle = _display(34, 36, 700, -0.03);
  static final title1 = _display(28, 32, 700, -0.03);
  static final title2 = _display(22, 26, 700, -0.02);
  static final cardTitle = _display(20, 24, 700, -0.02);
  static final ticketNumber = _display(52, 48, 800, -0.04);

  // Text (Inter)
  static final body = _sans(16, 24, 400);
  static final bodyStrong = _sans(16, 24, 600);
  static final callout = _sans(15, 22, 400);
  static final footnote = _sans(13, 18, 400);

  /// iOS inline nav-bar title once the large title collapses.
  static final navInline = _sans(17, 22, 600);

  /// iOS back button label.
  static final navBack = _sans(17, 22, 400);

  // Mono (JetBrains Mono)
  static final label = _mono(11, 14, 700, 0.1);
  static final tabLabel = _mono(10, 12, 600, 0.08);
  static final data = _mono(13, 20, 400, 0);
  static final dataStrong = _mono(13, 20, 700, 0);
  static final monoButton = _mono(12, 16, 700, 0.08);

  /// Stamps: label type at +0.12em.
  static final stamp = _mono(11, 14, 700, 0.12);
}

/// True at accessibility text sizes: receipts stack their rows and the stamp
/// drops below the item name.
bool isLargeText(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(16) >= 16 * 1.6;
