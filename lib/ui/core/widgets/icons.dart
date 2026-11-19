import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';

enum PdGlyph { vault, settings, scan, back, home, add }

class PdIcon extends StatelessWidget {
  const PdIcon(
    this.glyph, {
    this.size = Pd.iconMd,
    this.color = Pd.text,
    super.key,
  });

  final PdGlyph glyph;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _GlyphPainter(glyph, color),
  );
}

class _GlyphPainter extends CustomPainter {
  const _GlyphPainter(this.glyph, this.color);

  final PdGlyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    switch (glyph) {
      case PdGlyph.home:
        canvas.drawPath(
          Path()
            ..moveTo(3, 10)
            ..lineTo(12, 3)
            ..lineTo(21, 10)
            ..lineTo(21, 21)
            ..lineTo(15, 21)
            ..lineTo(15, 14)
            ..lineTo(9, 14)
            ..lineTo(9, 21)
            ..lineTo(3, 21)
            ..close(),
          stroke,
        );
      case PdGlyph.add:
        canvas.drawLine(const Offset(12, 5), const Offset(12, 19), stroke);
        canvas.drawLine(const Offset(5, 12), const Offset(19, 12), stroke);
      case PdGlyph.vault:
        canvas.drawRRect(
          RRect.fromLTRBR(3, 3, 21, 21, const Radius.circular(2)),
          stroke,
        );
        canvas.drawLine(const Offset(3, 12), const Offset(21, 12), stroke);
        canvas.drawLine(const Offset(10, 7.5), const Offset(14, 7.5), stroke);
        canvas.drawLine(const Offset(10, 16.5), const Offset(14, 16.5), stroke);
      case PdGlyph.settings:
        canvas.drawLine(const Offset(4, 7), const Offset(13, 7), stroke);
        canvas.drawLine(const Offset(17, 7), const Offset(20, 7), stroke);
        canvas.drawLine(const Offset(4, 17), const Offset(7, 17), stroke);
        canvas.drawLine(const Offset(11, 17), const Offset(20, 17), stroke);
        canvas.drawCircle(const Offset(15, 7), 2, stroke);
        canvas.drawCircle(const Offset(9, 17), 2, stroke);
      case PdGlyph.back:
        canvas.drawPath(
          Path()
            ..moveTo(15, 5)
            ..lineTo(8, 12)
            ..lineTo(15, 19),
          stroke..strokeWidth = 2.2,
        );
      case PdGlyph.scan:
        final shape = Path()
          ..moveTo(4, 8)
          ..lineTo(4, 5)
          ..quadraticBezierTo(4, 4, 5, 4)
          ..lineTo(8, 4)
          ..moveTo(16, 4)
          ..lineTo(19, 4)
          ..quadraticBezierTo(20, 4, 20, 5)
          ..lineTo(20, 8)
          ..moveTo(20, 16)
          ..lineTo(20, 19)
          ..quadraticBezierTo(20, 20, 19, 20)
          ..lineTo(16, 20)
          ..moveTo(8, 20)
          ..lineTo(5, 20)
          ..quadraticBezierTo(4, 20, 4, 19)
          ..lineTo(4, 16)
          ..moveTo(7, 12)
          ..lineTo(17, 12);
        canvas.drawPath(shape, stroke);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlyphPainter oldDelegate) =>
      oldDelegate.glyph != glyph || oldDelegate.color != color;
}

class PaperDrawerMark extends StatelessWidget {
  const PaperDrawerMark({this.size = 28, super.key});

  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size(size, size * 34 / 30),
    painter: const _MarkPainter(),
  );
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 30, size.height / 34);
    final paper = Path()
      ..moveTo(3, 3)
      ..lineTo(27, 3)
      ..lineTo(27, 29);
    for (var x = 23; x >= 3; x -= 4) {
      paper.lineTo(x.toDouble(), (x - 3) % 8 == 0 ? 29 : 26);
    }
    paper.close();
    canvas.drawPath(paper, Paint()..color = Pd.lime);
    canvas.drawPath(
      Path()
        ..moveTo(9.5, 15.5)
        ..lineTo(13.5, 19.5)
        ..lineTo(20.5, 11.5),
      Paint()
        ..color = Pd.bg
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) => false;
}
