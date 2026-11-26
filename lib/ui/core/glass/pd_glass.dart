import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';
import 'package:native_liquid_glass/native_liquid_glass.dart';

import '../theme/pd_colors.dart';
import '../theme/pd_metrics.dart';
import '../theme/pd_theme.dart';
import 'glass_scope.dart';

/// Glass outlines. Glass is always a capsule, a circle or a rounded panel.
enum PdGlassShape { capsule, circle, rounded }

/// Glass tints. Only Scan is tinted.
enum PdGlassTint { none, lime }

/// A glass surface for a control (never for content).
///
/// - [PdGlassMode.native]: system Liquid Glass behind [child]
///   (`LiquidGlassContainer`); the system handles Reduce Transparency and
///   Increase Contrast.
/// - [PdGlassMode.fallback]: the design-system recipe: `glass-fill` (80%)
///   over a blur 20 / saturate 180% backdrop, a 1 pt `glass-rim` highlight on
///   top, a `glass-rim-shade` ring and `shadow-glass`.
/// - [PdGlassMode.solid] (Reduce Transparency): solid `surface-2` (lime for
///   the tinted variant), no blur.
/// - Increase Contrast (`MediaQuery.highContrastOf`) adds a 1 pt `line`
///   border in fallback and solid modes.
final class PdGlass extends StatelessWidget {
  const PdGlass({
    required this.child,
    this.shape = PdGlassShape.capsule,
    this.cornerRadius = PdRadius.lg,
    this.tint = PdGlassTint.none,
    this.shadow = true,
    super.key,
  });

  final Widget child;
  final PdGlassShape shape;

  /// Corner radius for [PdGlassShape.rounded].
  final double cornerRadius;
  final PdGlassTint tint;

  /// Whether to cast `shadow-glass` (fallback and solid modes).
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final colors = context.pd.colors;
    return switch (PdGlassScope.modeOf(context)) {
      PdGlassMode.native => _native(colors),
      PdGlassMode.fallback => _fallback(context, colors),
      PdGlassMode.solid => _solid(context, colors),
    };
  }

  Widget _native(PdColors colors) => LiquidGlassContainer(
    config: LiquidGlassConfig(
      shape: switch (shape) {
        PdGlassShape.capsule => LiquidGlassEffectShape.capsule,
        PdGlassShape.circle => LiquidGlassEffectShape.circle,
        PdGlassShape.rounded => LiquidGlassEffectShape.rect,
      },
      cornerRadius: shape == PdGlassShape.rounded ? cornerRadius : null,
      tint: switch (tint) {
        PdGlassTint.none => null,
        PdGlassTint.lime => colors.glassLime,
      },
    ),
    child: child,
  );

  Widget _fallback(BuildContext context, PdColors colors) {
    final lime = tint == PdGlassTint.lime;
    final painter = _GlassEdgePainter(
      shape: shape,
      cornerRadius: cornerRadius,
      highlight: lime ? colors.glassLimeRim : colors.glassRim,
      ring: lime ? colors.glassLimeRimShade : colors.glassRimShade,
      contrastLine: MediaQuery.highContrastOf(context) ? colors.line : null,
    );
    return _Shadowed(
      shape: shape,
      cornerRadius: cornerRadius,
      shadows: shadow ? PdShadows.glass(colors) : const [],
      child: ClipPath(
        clipper: _ShapeClipper(shape, cornerRadius),
        child: BackdropFilter(
          filter: _backdrop,
          child: ColoredBox(
            color: lime ? colors.glassLime : colors.glassFill,
            child: CustomPaint(foregroundPainter: painter, child: child),
          ),
        ),
      ),
    );
  }

  Widget _solid(BuildContext context, PdColors colors) {
    final lime = tint == PdGlassTint.lime;
    return _Shadowed(
      shape: shape,
      cornerRadius: cornerRadius,
      shadows: shadow ? PdShadows.glass(colors) : const [],
      child: ClipPath(
        clipper: _ShapeClipper(shape, cornerRadius),
        child: ColoredBox(
          color: lime ? colors.lime : colors.surface2,
          child: CustomPaint(
            foregroundPainter: MediaQuery.highContrastOf(context)
                ? _GlassEdgePainter(
                    shape: shape,
                    cornerRadius: cornerRadius,
                    contrastLine: colors.line,
                  )
                : null,
            child: child,
          ),
        ),
      ),
    );
  }

  /// Blur first, then saturate (CSS `blur(20px) saturate(180%)`).
  static final ImageFilter _backdrop = ImageFilter.compose(
    outer: ColorFilter.matrix(_saturation(PdEffects.glassSaturate)),
    inner: ImageFilter.blur(
      sigmaX: PdEffects.glassBlur,
      sigmaY: PdEffects.glassBlur,
    ),
  );

  /// The CSS `saturate()` matrix.
  static List<double> _saturation(double s) => [
    0.213 + 0.787 * s, 0.715 - 0.715 * s, 0.072 - 0.072 * s, 0, 0, //
    0.213 - 0.213 * s, 0.715 + 0.285 * s, 0.072 - 0.072 * s, 0, 0, //
    0.213 - 0.213 * s, 0.715 - 0.715 * s, 0.072 + 0.928 * s, 0, 0, //
    0, 0, 0, 1, 0, //
  ];
}

/// The outline of a glass [shape] inside [size].
RRect pdGlassOutline(PdGlassShape shape, double cornerRadius, Size size) {
  final rect = Offset.zero & size;
  final radius = switch (shape) {
    PdGlassShape.capsule || PdGlassShape.circle => size.shortestSide / 2,
    PdGlassShape.rounded => math.min(cornerRadius, size.shortestSide / 2),
  };
  return RRect.fromRectAndRadius(rect, Radius.circular(radius));
}

final class _ShapeClipper extends CustomClipper<Path> {
  const _ShapeClipper(this.shape, this.cornerRadius);

  final PdGlassShape shape;
  final double cornerRadius;

  @override
  Path getClip(Size size) =>
      Path()..addRRect(pdGlassOutline(shape, cornerRadius, size));

  @override
  bool shouldReclip(_ShapeClipper oldClipper) =>
      oldClipper.shape != shape || oldClipper.cornerRadius != cornerRadius;
}

final class _Shadowed extends StatelessWidget {
  const _Shadowed({
    required this.shape,
    required this.cornerRadius,
    required this.shadows,
    required this.child,
  });

  final PdGlassShape shape;
  final double cornerRadius;
  final List<BoxShadow> shadows;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      shape: shape == PdGlassShape.circle ? BoxShape.circle : BoxShape.rectangle,
      borderRadius: switch (shape) {
        PdGlassShape.circle => null,
        PdGlassShape.capsule => BorderRadius.circular(PdRadius.pill),
        PdGlassShape.rounded => BorderRadius.circular(cornerRadius),
      },
      boxShadow: shadows,
    ),
    child: child,
  );
}

/// Paints the rim: a 1 pt highlight along the top edge (CSS
/// `inset 0 1px 0`), a 1 pt ring (`inset 0 0 0 1px`) and, with Increase
/// Contrast, a 1 pt `line` border.
final class _GlassEdgePainter extends CustomPainter {
  const _GlassEdgePainter({
    required this.shape,
    required this.cornerRadius,
    this.highlight,
    this.ring,
    this.contrastLine,
  });

  final PdGlassShape shape;
  final double cornerRadius;
  final Color? highlight;
  final Color? ring;
  final Color? contrastLine;

  @override
  void paint(Canvas canvas, Size size) {
    final outline = pdGlassOutline(shape, cornerRadius, size);
    final highlight = this.highlight;
    if (highlight != null) {
      final outer = Path()..addRRect(outline);
      final crescent = Path.combine(
        PathOperation.difference,
        outer,
        outer.shift(const Offset(0, 1)),
      );
      canvas.drawPath(crescent, Paint()..color = highlight);
    }
    void stroke(Color color) => canvas.drawRRect(
      outline.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = color,
    );
    final ring = this.ring;
    if (ring != null) stroke(ring);
    final contrastLine = this.contrastLine;
    if (contrastLine != null) stroke(contrastLine);
  }

  @override
  bool shouldRepaint(_GlassEdgePainter oldDelegate) =>
      oldDelegate.shape != shape ||
      oldDelegate.cornerRadius != cornerRadius ||
      oldDelegate.highlight != highlight ||
      oldDelegate.ring != ring ||
      oldDelegate.contrastLine != contrastLine;
}
