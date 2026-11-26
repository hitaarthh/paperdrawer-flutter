import 'package:flutter/widgets.dart';

/// Dynamic Type helpers.
///
/// Flutter behaviour: iOS's text size setting arrives as
/// `MediaQuery.textScalerOf(context)`, one scaler for every style.
/// PaperDrawer rules: content scales fully; floating glass chrome caps at
/// [chromeMaxScale]; at accessibility sizes layouts stack.
abstract final class PdDynamicType {
  /// iOS Body is 17 pt at the default size.
  static const double bodySize = 17;

  /// iOS Body at the first accessibility size (AX1) is 28 pt. From here on,
  /// data rows stack and the DeadlineCard number moves above the title.
  static const double accessibilityBodySize = 28;

  /// iOS Body at the largest accessibility size (AX5) is 53 pt: 53 / 17.
  static const double largestScale = 53 / bodySize;

  /// The most the floating glass chrome (tab bar, Scan, DeadlineAccessory,
  /// Toast, toolbar buttons) scales its text. iOS system bars stop growing
  /// similarly and rely on the Large Content Viewer.
  static const double chromeMaxScale = 1.5;

  /// True from the first accessibility text size up.
  static bool isAccessibilitySize(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(bodySize) >=
      accessibilityBodySize;

  /// Caps the text scale of [child] at [chromeMaxScale].
  static Widget chrome({required Widget child}) =>
      MediaQuery.withClampedTextScaling(
        maxScaleFactor: chromeMaxScale,
        child: child,
      );
}
