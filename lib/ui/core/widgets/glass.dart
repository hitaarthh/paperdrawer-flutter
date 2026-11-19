import 'dart:ui' show ImageFilter;

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:native_liquid_glass/native_liquid_glass.dart';

import '../theme/tokens.dart';

List<NavigatorObserver> pdGlassNavigatorObservers() => [
  if (NativeLiquidGlassUtils.supportsLiquidGlass)
    LiquidGlassNavigatorObserver(),
];

bool pdNativeGlassVisible(BuildContext context) =>
    NativeLiquidGlassUtils.supportsLiquidGlass &&
    (context.dependOnInheritedWidgetOfExactType<_GlassVisibility>()?.visible ??
        true);

class PdGlassRouteBoundary extends StatelessWidget {
  const PdGlassRouteBoundary({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!NativeLiquidGlassUtils.supportsLiquidGlass) return child;
    final route = ModalRoute.of(context);
    if (route == null) return child;
    final primary = route.animation;
    final secondary = route.secondaryAnimation;
    return AnimatedBuilder(
      animation: Listenable.merge([primary, secondary]),
      child: child,
      builder: (context, child) => _GlassVisibility(
        // UIKit can sample the wrong part of Flutter's surface when a
        // platform view moves during a push or swipe-back animation.
        visible:
            route.isCurrent &&
            (primary?.isCompleted ?? true) &&
            (secondary?.isDismissed ?? true),
        child: child!,
      ),
    );
  }
}

class _GlassVisibility extends InheritedWidget {
  const _GlassVisibility({required this.visible, required super.child});

  final bool visible;

  @override
  bool updateShouldNotify(_GlassVisibility oldWidget) =>
      oldWidget.visible != visible;
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
    if (inSurface && pdNativeGlassVisible(context)) {
      return Semantics(
        button: true,
        enabled: onPressed != null,
        label: label,
        onTap: onPressed,
        excludeSemantics: true,
        child: LiquidGlassButton.icon(
          icon: NativeLiquidGlassIcon.sfSymbol(systemIcon),
          size: Pd.tapMin,
          iconSize: Pd.iconSm,
          onPressed: onPressed,
          interactive: !MediaQuery.disableAnimationsOf(context),
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
