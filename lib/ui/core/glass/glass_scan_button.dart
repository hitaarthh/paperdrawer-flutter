import 'package:flutter/widgets.dart';
import 'package:native_liquid_glass/native_liquid_glass.dart';

import '../theme/pd_metrics.dart';
import '../theme/pd_theme.dart';
import '../widgets/glass.dart' show PdNativeGlassTouch;
import '../widgets/icons.dart';
import 'glass_scope.dart';
import 'pd_glass.dart';
import 'pd_pressable.dart';

/// The one lime glass circle: Scan or add. Tap opens the Add sheet;
/// long-press opens the camera directly (fallback glass only, see
/// [onLongPress]).
///
/// No text inside, no badge. VoiceOver: "Scan or add, button".
final class GlassScanButton extends StatelessWidget {
  const GlassScanButton({
    required this.onPressed,
    this.onLongPress,
    this.semanticLabel = 'Scan or add',
    this.size = PdSize.tabBarHeight,
    this.systemIcon = 'doc.viewfinder',
    super.key = const ValueKey('scan-or-add'),
  });

  final VoidCallback? onPressed;

  /// Opens the camera directly. The native iOS 26 button has no long-press,
  /// so it only fires with fallback glass.
  final VoidCallback? onLongPress;
  final String semanticLabel;

  /// [PdSize.tabBarHeight] at rest, [PdSize.tabBarMin] when minimised.
  final double size;

  /// SF Symbol for the native button.
  final String systemIcon;

  @override
  Widget build(BuildContext context) {
    final colors = context.pd.colors;
    if (PdGlassScope.modeOf(context) == PdGlassMode.native) {
      return Semantics(
        button: true,
        enabled: onPressed != null,
        label: semanticLabel,
        onTap: onPressed,
        excludeSemantics: true,
        child: PdNativeGlassTouch(
          child: LiquidGlassButton.icon(
            icon: NativeLiquidGlassIcon.sfSymbol(systemIcon),
            size: size,
            iconSize: PdSize.iconBar,
            iconColor: colors.onLime,
            tint: colors.glassLime,
            style: LiquidGlassButtonStyle.prominentGlass,
            onPressed: onPressed,
            interactive: !MediaQuery.disableAnimationsOf(context),
          ),
        ),
      );
    }
    return PdPressable(
      semanticLabel: semanticLabel,
      onPressed: onPressed,
      onLongPress: onLongPress,
      child: PdGlass(
        shape: PdGlassShape.circle,
        tint: PdGlassTint.lime,
        child: SizedBox.square(
          dimension: size,
          child: Center(
            child: PdIcon(
              PdGlyph.scan,
              size: PdSize.iconBar,
              color: colors.onLime,
            ),
          ),
        ),
      ),
    );
  }
}
