import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/type.dart';
import '../../../core/widgets/icons.dart';

/// Intro step 2 art (iOS Intro 2 · Remember): two countdown tickets and a
/// reminder card, drawn on the 390×360 intro art canvas.
///
/// The parent sizes this to exactly 390×360 and scales it with a
/// [FittedBox], so every coordinate below is the mockup's own. It is a
/// picture, so its text ignores Dynamic Type.
class RememberArt extends StatelessWidget {
  const RememberArt({super.key});

  @override
  Widget build(BuildContext context) => MediaQuery.withNoTextScaling(
    child: DefaultTextStyle(
      style: const TextStyle(
        fontFamily: PdType.sans,
        color: Pd.ink,
        decoration: TextDecoration.none,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 20,
            right: 20,
            top: 8,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                _Ticket(
                  color: Pd.signal,
                  angle: -2,
                  perforation: Color(0x590E1311),
                  days: '02',
                  kicker: 'RETURN WINDOW CLOSES · FRI',
                  kickerColor: Pd.ink,
                  title: 'Wireless earbuds',
                  sub: 'Start the return now.',
                ),
                _Ticket(
                  color: Pd.paper,
                  angle: 1.5,
                  perforation: Color(0x400E1311),
                  days: '12',
                  kicker: 'POLICY RENEWS · 30 NOV',
                  kickerColor: Pd.dueInk,
                  title: 'Family health policy',
                  sub: 'Renew before it lapses.',
                ),
              ],
            ),
          ),
          const Positioned(left: 20, right: 20, top: 270, child: _Reminder()),
        ],
      ),
    ),
  );
}

// Type from the mockup. CSS `line-height: normal` is approximated with each
// family's natural line gap (JetBrains Mono 1.32, Inter 1.21).

TextStyle _bricolage(double size, double height, int weight, double em) =>
    TextStyle(
      fontFamily: PdType.display,
      fontSize: size,
      height: height,
      leadingDistribution: TextLeadingDistribution.even,
      fontWeight: FontWeight.values[(weight ~/ 100) - 1],
      fontVariations: [
        FontVariation.weight(weight.toDouble()),
        FontVariation.opticalSize(size),
      ],
      letterSpacing: size * em,
    );

TextStyle _inter(double size, double height, int weight) => TextStyle(
  fontFamily: PdType.sans,
  fontSize: size,
  height: height,
  leadingDistribution: TextLeadingDistribution.even,
  fontWeight: FontWeight.values[(weight ~/ 100) - 1],
  fontVariations: [FontVariation.weight(weight.toDouble())],
);

TextStyle _mono(double size, int weight, double em) => TextStyle(
  fontFamily: PdType.mono,
  fontSize: size,
  height: 1.32,
  leadingDistribution: TextLeadingDistribution.even,
  fontWeight: FontWeight.values[(weight ~/ 100) - 1],
  fontVariations: [FontVariation.weight(weight.toDouble())],
  letterSpacing: size * em,
);

final _number = _bricolage(50, 0.9, 800, -0.04);
final _days = _mono(11, 700, 0.1);
final _kicker = _mono(10, 700, 0.1);
final _title = _bricolage(20, 1.1, 700, -0.02);
final _sub = _inter(
  13,
  1.35,
  500,
).copyWith(color: Pd.ink.withValues(alpha: .85));
final _reminderLabel = _mono(10, 400, 0.1).copyWith(color: Pd.textMuted);
final _reminderTitle = _inter(14, 1.21, 600).copyWith(color: Pd.text);

/// Stub content width 92 + 12px padding each side + the 2px dashed border
/// (the mockup's stub is `content-box`).
const _stubWidth = 92.0 + 12 * 2 + 2;

class _Ticket extends StatelessWidget {
  const _Ticket({
    required this.color,
    required this.angle,
    required this.perforation,
    required this.days,
    required this.kicker,
    required this.kickerColor,
    required this.title,
    required this.sub,
  });

  final Color color;

  /// Rotation in degrees, about the ticket's centre like CSS `rotate()`.
  final double angle;
  final Color perforation;
  final String days;
  final String kicker;
  final Color kickerColor;
  final String title;
  final String sub;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: angle * math.pi / 180,
    child: ClipPath(
      clipper: const _StubClipper(),
      child: CustomPaint(
        painter: _StubPainter(color: color, perforation: perforation),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 116),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: _stubWidth,
                  child: Padding(
                    // Right padding includes the 2px perforation border.
                    padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      spacing: 2,
                      children: [
                        Text(days, style: _number, maxLines: 1),
                        Text('DAYS', style: _days, maxLines: 1),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 18, 14),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 4,
                      children: [
                        Text(
                          kicker,
                          style: _kicker.copyWith(color: kickerColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          title,
                          style: _title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          sub,
                          style: _sub,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// The mockup's `.stub` mask: a rounded rect with a 10px half-circle bitten
/// out of the left and right edges at mid-height.
Path _stubPath(Size size) {
  const notch = 10.0;
  final ticket = Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(Pd.rSm),
      ),
    );
  final notches = Path()
    ..addOval(
      Rect.fromCircle(center: Offset(0, size.height / 2), radius: notch),
    )
    ..addOval(
      Rect.fromCircle(
        center: Offset(size.width, size.height / 2),
        radius: notch,
      ),
    );
  return Path.combine(PathOperation.difference, ticket, notches);
}

class _StubClipper extends CustomClipper<Path> {
  const _StubClipper();

  @override
  Path getClip(Size size) => _stubPath(size);

  @override
  bool shouldReclip(_StubClipper oldClipper) => false;
}

/// Fills the ticket and draws the stub's 2px dashed right border.
class _StubPainter extends CustomPainter {
  const _StubPainter({required this.color, required this.perforation});

  final Color color;
  final Color perforation;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(_stubPath(size), Paint()..color = color);

    // CSS dashed borders: dashes 3× the border width, gaps stretched so the
    // line starts and ends on a full dash.
    const width = 2.0;
    const dash = width * 3;
    final x = _stubWidth - width / 2;
    final count = math.max(1, ((size.height + dash) / (dash * 2)).floor());
    final gap = count > 1 ? (size.height - count * dash) / (count - 1) : 0.0;
    final paint = Paint()
      ..color = perforation
      ..strokeWidth = width;
    for (var i = 0; i < count; i++) {
      final top = i * (dash + gap);
      canvas.drawLine(Offset(x, top), Offset(x, top + dash), paint);
    }
  }

  @override
  bool shouldRepaint(_StubPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.perforation != perforation;
}

class _Reminder extends StatelessWidget {
  const _Reminder();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Pd.surface2,
      borderRadius: BorderRadius.circular(Pd.rSm),
      border: Border.all(color: Pd.hairline),
    ),
    child: Padding(
      // 14/16 padding plus the 1px border.
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 17),
      child: Row(
        spacing: 12,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Pd.bg,
              borderRadius: BorderRadius.circular(8),
            ),
            // The mockup's 18×20 svg box fits the 30×34 mark to 20px tall.
            child: const PaperDrawerMark(size: 20 * 30 / 34),
          ),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(
                  'REMINDER · 7 DAYS BEFORE',
                  style: _reminderLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Washing machine warranty ends 10 Dec',
                  style: _reminderTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
