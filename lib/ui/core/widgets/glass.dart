import 'dart:ui' show ImageFilter;

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/foundation.dart' show Factory;
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart'
    show BoxHitTestResult, RenderObject, RenderProxyBox, RenderUiKitView;
import 'package:native_liquid_glass/native_liquid_glass.dart';

import '../theme/tokens.dart';

List<NavigatorObserver> pdGlassNavigatorObservers() => [
  if (NativeLiquidGlassUtils.supportsLiquidGlass)
    LiquidGlassNavigatorObserver(),
];

/// Lets UIKit handle touches from pointer-down on a native glass control.
class PdNativeGlassTouch extends SingleChildRenderObjectWidget {
  const PdNativeGlassTouch({required Widget super.child, super.key});

  @override
  RenderProxyBox createRenderObject(BuildContext context) =>
      _NativeGlassTouchBox();
}

class _NativeGlassTouchBox extends RenderProxyBox {
  static final _recognizers = {
    Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
  };

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    // native_liquid_glass 0.3.1 supplies callback-free tap recognizers, which
    // do not enter Flutter's arena. Configure the UIKit view before hit testing
    // because the plugin can create it asynchronously or update its recognizers.
    if (child case final view?) _enableNativeTouch(view);
    return super.hitTestChildren(result, position: position);
  }

  void _enableNativeTouch(RenderObject view) {
    if (view is RenderUiKitView) {
      view.updateGestureRecognizers(_recognizers);
    } else {
      view.visitChildren(_enableNativeTouch);
    }
  }
}

class PdGlassSurface extends StatelessWidget {
  const PdGlassSurface({required this.child, super.key});

  final Widget child;

  static const radius = BorderRadius.all(Radius.circular(Pd.rPill));
  static final _blur = ImageFilter.blur(
    sigmaX: Pd.dockBlur,
    sigmaY: Pd.dockBlur,
  );

  @override
  Widget build(BuildContext context) {
    final highContrast = MediaQuery.highContrastOf(context);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        enabled: !highContrast,
        filter: _blur,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: highContrast ? Pd.surface1 : null,
            gradient: highContrast
                ? null
                : const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Pd.dockGlassTop, Pd.dockGlassBottom],
                  ),
            borderRadius: radius,
          ),
          child: CustomPaint(
            foregroundPainter: _GlassRim(highContrast),
            child: child,
          ),
        ),
      ),
    );
  }
}

class PdGlassIcon extends StatelessWidget {
  const PdGlassIcon({
    required this.icon,
    required this.systemIcon,
    required this.label,
    required this.onPressed,
    this.inSurface = true,
    super.key,
  });

  final Widget icon;
  final String systemIcon;
  final String label;
  final VoidCallback? onPressed;
  final bool inSurface;

  @override
  Widget build(BuildContext context) {
    if (inSurface && NativeLiquidGlassUtils.supportsLiquidGlass) {
      return Semantics(
        button: true,
        enabled: onPressed != null,
        label: label,
        onTap: onPressed,
        excludeSemantics: true,
        child: PdNativeGlassTouch(
          child: LiquidGlassButton.icon(
            icon: NativeLiquidGlassIcon.sfSymbol(systemIcon),
            size: Pd.tapMin,
            iconSize: Pd.iconSm,
            onPressed: onPressed,
            interactive: !MediaQuery.disableAnimationsOf(context),
          ),
        ),
      );
    }
    final control = Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: CupertinoButton(
        onPressed: onPressed,
        minimumSize: const Size.square(Pd.tapMin),
        padding: EdgeInsets.zero,
        borderRadius: PdGlassSurface.radius,
        pressedOpacity: .7,
        focusColor: Pd.lime,
        child: IconTheme.merge(
          data: const IconThemeData(color: Pd.text, size: Pd.iconSm),
          child: icon,
        ),
      ),
    );
    return inSurface ? PdGlassSurface(child: control) : control;
  }
}

class _GlassRim extends CustomPainter {
  const _GlassRim(this.highContrast);

  final bool highContrast;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Pd.line;
    if (!highContrast) {
      paint.shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Pd.dockRimLight, Pd.dockRimShade, Pd.dockRimLight],
      ).createShader(rect);
    }
    canvas.drawRRect(
      PdGlassSurface.radius
          .toRRect(rect)
          .scaleRadii()
          .deflate(paint.strokeWidth / 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(_GlassRim oldDelegate) =>
      oldDelegate.highContrast != highContrast;
}
