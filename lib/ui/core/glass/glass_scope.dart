import 'package:flutter/widgets.dart';
import 'package:native_liquid_glass/native_liquid_glass.dart'
    show NativeLiquidGlassUtils;

/// How glass is drawn right now.
enum PdGlassMode {
  /// iOS 26 system Liquid Glass through `native_liquid_glass`. The system
  /// handles Reduce Transparency and Increase Contrast itself.
  native,

  /// The Flutter recipe: 80% `glass-fill`, blur 20, saturate 180%, rim,
  /// `shadow-glass`.
  fallback,

  /// Reduce Transparency without native glass: solid `surface-2`.
  solid,
}

/// Supplies the glass settings Flutter's `MediaQuery` doesn't carry.
///
/// Flutter has no Reduce Transparency flag, so the composition root reads it
/// from iOS (`UIAccessibility.isReduceTransparencyEnabled`) and passes it
/// here; tests set it directly. Increase Contrast is
/// `MediaQuery.highContrastOf` and Reduce Motion is
/// `MediaQuery.disableAnimationsOf` (both standard Flutter).
final class PdGlassScope extends InheritedWidget {
  const PdGlassScope({
    required super.child,
    this.reduceTransparency = false,
    this.nativeGlass,
    super.key,
  });

  /// iOS Reduce Transparency is on.
  final bool reduceTransparency;

  /// Whether to use native glass. `null` asks the plugin (iOS 26 and up).
  final bool? nativeGlass;

  static PdGlassScope? _of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PdGlassScope>();

  /// The glass mode for [context].
  static PdGlassMode modeOf(BuildContext context) {
    final scope = _of(context);
    final native =
        scope?.nativeGlass ?? NativeLiquidGlassUtils.supportsLiquidGlass;
    if (native) return PdGlassMode.native;
    if (scope?.reduceTransparency ?? false) return PdGlassMode.solid;
    return PdGlassMode.fallback;
  }

  /// Whether iOS Reduce Transparency is on.
  static bool reduceTransparencyOf(BuildContext context) =>
      _of(context)?.reduceTransparency ?? false;

  @override
  bool updateShouldNotify(PdGlassScope oldWidget) =>
      oldWidget.reduceTransparency != reduceTransparency ||
      oldWidget.nativeGlass != nativeGlass;
}
