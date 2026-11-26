import 'package:flutter/widgets.dart';
import 'package:native_liquid_glass/native_liquid_glass.dart';

import '../theme/pd_dynamic_type.dart';
import '../theme/pd_metrics.dart';
import '../theme/pd_theme.dart';
import '../widgets/glass.dart' show PdNativeGlassTouch;
import 'glass_scope.dart';
import 'pd_glass.dart';
import 'pd_pressable.dart';

/// A glass toolbar button at the top of a screen: back, search, account,
/// share, more (round) or a one-word label like "Edit" (capsule).
///
/// Never lime (only Scan is). On iOS 26 it is the system glass button; the
/// fallback is a 44 pt glass circle with a 22 pt `text` icon. The hit area is
/// always at least 44 pt, even when [visualSize] is smaller (36 pt sheet
/// close button).
final class GlassToolbarButton extends StatelessWidget {
  /// A round icon button. [icon] is drawn by the fallback; [systemIcon] is
  /// the SF Symbol for native glass.
  const GlassToolbarButton.icon({
    required Widget this.icon,
    required String this.systemIcon,
    required this.semanticLabel,
    required this.onPressed,
    this.visualSize = PdSize.glassButton,
    this.iconSize = PdSize.iconBar,
    this.grouped = false,
    super.key,
  }) : label = null;

  /// A capsule with a one-word label.
  const GlassToolbarButton.label({
    required String this.label,
    required this.onPressed,
    String? semanticLabel,
    this.grouped = false,
    super.key,
  }) : icon = null,
       systemIcon = null,
       semanticLabel = semanticLabel ?? label,
       visualSize = PdSize.glassButton,
       iconSize = PdSize.iconBar;

  final Widget? icon;
  final String? systemIcon;
  final String? label;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final double visualSize;
  final double iconSize;

  /// Inside a [GlassToolbarGroup]: no glass of its own.
  final bool grouped;

  @override
  Widget build(BuildContext context) {
    final native = PdGlassScope.modeOf(context) == PdGlassMode.native;
    if (native && !grouped) return _native(context);
    final pd = context.pd;
    final label = this.label;
    final Widget content = label == null
        ? SizedBox.square(
            dimension: visualSize,
            child: Center(
              child: IconTheme.merge(
                data: IconThemeData(color: pd.colors.text, size: iconSize),
                child: icon ?? const SizedBox.shrink(),
              ),
            ),
          )
        : SizedBox(
            height: visualSize,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: PdSpace.s4),
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  maxLines: 1,
                  style: pd.type.subhead.copyWith(color: pd.colors.text),
                ),
              ),
            ),
          );
    return PdDynamicType.chrome(
      child: PdPressable(
        semanticLabel: semanticLabel,
        onPressed: onPressed,
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: grouped
              ? content
              : PdGlass(
                  shape: label == null
                      ? PdGlassShape.circle
                      : PdGlassShape.capsule,
                  child: content,
                ),
        ),
      ),
    );
  }

  Widget _native(BuildContext context) {
    final colors = context.pd.colors;
    final label = this.label;
    final systemIcon = this.systemIcon;
    final interactive = !MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: semanticLabel,
      onTap: onPressed,
      excludeSemantics: true,
      child: PdNativeGlassTouch(
        child: label == null && systemIcon != null
            ? LiquidGlassButton.icon(
                icon: NativeLiquidGlassIcon.sfSymbol(systemIcon),
                size: visualSize,
                iconSize: iconSize,
                iconColor: colors.text,
                onPressed: onPressed,
                interactive: interactive,
              )
            : LiquidGlassButton(
                label: label ?? semanticLabel,
                height: PdSize.glassButton,
                style: LiquidGlassButtonStyle.glass,
                labelColor: colors.text,
                onPressed: onPressed,
                interactive: interactive,
              ),
      ),
    );
  }
}

/// Related toolbar buttons in one glass capsule (`space-2` apart from other
/// groups), the way iOS merges adjacent toolbar items. At most three.
final class GlassToolbarGroup extends StatelessWidget {
  const GlassToolbarGroup({required this.children, super.key});

  /// Buttons built with `grouped: true`; at most three on one side.
  final List<GlassToolbarButton> children;

  @override
  Widget build(BuildContext context) => PdGlass(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: PdSpace.s1 / 2),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    ),
  );
}
