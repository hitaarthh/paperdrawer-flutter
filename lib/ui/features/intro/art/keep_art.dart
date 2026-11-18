import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/type.dart';
import '../../../core/widgets/paper.dart';

/// Intro 1 · Keep: a shop receipt filed on top of a policy schedule, with a
/// FILED stamp. Drawn on the 390×360 intro art canvas; coordinates come
/// straight from the mockup (art top 140 on the artboard, so +22 here).
///
/// It is a picture, so its text ignores Dynamic Type. The ₹ glyph is not in
/// the bundled JetBrains Mono and falls back to the system font, as elsewhere.
class KeepArt extends StatelessWidget {
  const KeepArt({super.key});

  /// Mockup art container top (140) minus the canvas origin (118).
  static const _dy = 22.0;

  @override
  Widget build(BuildContext context) => MediaQuery.withNoTextScaling(
    // Own base style, so the art never picks up a host's text decoration.
    child: DefaultTextStyle(
      style: _line,
      child: const Stack(
        clipBehavior: Clip.none,
        children: [
          // Content-box widths: mockup width plus 16 + 16 horizontal padding.
          Positioned(
            left: 150,
            top: 30 + _dy,
            width: 200 + 32,
            child: _Tilted(degrees: 6, child: _PolicySchedule()),
          ),
          Positioned(
            left: 40,
            top: 56 + _dy,
            width: 210 + 32,
            child: _Tilted(degrees: -4, child: _Receipt()),
          ),
          Positioned(
            left: 168,
            top: 214 + _dy,
            child: _Tilted(degrees: -12, child: _FiledStamp()),
          ),
        ],
      ),
    ),
  );
}

class _Tilted extends StatelessWidget {
  const _Tilted({required this.degrees, required this.child});

  final double degrees;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Transform.rotate(angle: degrees * math.pi / 180, child: child);
}

/// Mono at the mockup's 1.8 line height, leading split evenly like CSS.
TextStyle _mono(
  double size, {
  int weight = 400,
  double em = 0,
  Color color = Pd.ink2,
}) => TextStyle(
  fontFamily: PdType.mono,
  fontSize: size,
  height: 1.8,
  leadingDistribution: TextLeadingDistribution.even,
  fontWeight: FontWeight.values[(weight ~/ 100) - 1],
  fontVariations: [FontVariation.weight(weight.toDouble())],
  letterSpacing: size * em,
  color: color,
);

final _line = _mono(10);
final _muted = _mono(10, color: Pd.inkMuted);
final _strong = _mono(10, weight: 700);

class _Pair extends StatelessWidget {
  const _Pair(this.left, this.right, {this.leftStyle, this.rightStyle});

  final String left;
  final String right;
  final TextStyle? leftStyle;
  final TextStyle? rightStyle;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(left, style: leftStyle ?? _muted),
      Text(right, style: rightStyle ?? _line),
    ],
  );
}

class _PolicySchedule extends StatelessWidget {
  const _PolicySchedule();

  static const _rule = Padding(
    padding: EdgeInsets.symmetric(vertical: Pd.s2),
    child: SolidRule(),
  );

  @override
  Widget build(BuildContext context) => DocumentPaper(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('POLICY SCHEDULE', style: _mono(10, weight: 700, em: 0.1)),
        Text('Shield General Insurance', style: _muted),
        _rule,
        const _Pair('PLAN', 'FAMILY FLOATER'),
        _Pair('SUM INSURED', '₹10,00,000', rightStyle: _strong),
        const _Pair('RENEWAL', '30-11-2026'),
        _rule,
        Text('POLICY NO. SGI-HF-448120', style: _muted),
      ],
    ),
  );
}

class _Receipt extends StatelessWidget {
  const _Receipt();

  static const _rule = Padding(
    padding: EdgeInsets.symmetric(vertical: Pd.s2),
    child: DashedRule(),
  );

  @override
  Widget build(BuildContext context) {
    final total = _mono(12, weight: 700);
    return ReceiptPaper(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'SHARMA ELECTRONICS',
            textAlign: TextAlign.center,
            style: _mono(11, weight: 700, em: 0.12),
          ),
          Text('Mall Road, Kanpur', textAlign: TextAlign.center, style: _muted),
          _rule,
          Text('SPLIT AC 1.5T 5-STAR', style: _line),
          const _Pair('14-11-2026', 'INV 2026/1142'),
          _rule,
          _Pair('TOTAL', '₹38,490', leftStyle: total, rightStyle: total),
          Text('WARRANTY: 1 YR', style: _muted),
          Text('5 YR ON COMPRESSOR', style: _muted),
          _rule,
          Text(
            'THANK YOU · VISIT AGAIN',
            textAlign: TextAlign.center,
            style: _muted,
          ),
        ],
      ),
    );
  }
}

/// The FILED stamp. Not a `StampKind` status, so it is drawn here in the
/// covered-green stamp ink over a translucent paper wash.
class _FiledStamp extends StatelessWidget {
  const _FiledStamp();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Pd.paper.withValues(alpha: 0.55),
      border: Border.all(color: Pd.stampCovered, width: 2),
      borderRadius: BorderRadius.circular(Pd.rXs),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: Pd.s2, vertical: 3),
      child: Text(
        'FILED',
        softWrap: false,
        style: PdType.stamp.copyWith(color: Pd.stampCovered),
      ),
    ),
  );
}
