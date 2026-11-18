import 'dart:math' as math;
import 'dart:ui' show PointMode;

import 'package:material_ui/material_ui.dart';

import '../theme/drawer_theme.dart';

class DrawerMark extends StatelessWidget {
  const DrawerMark({
    this.size = 28,
    this.fill = drawerLime,
    this.ink = drawerInk,
    super.key,
  });

  final double size;
  final Color fill;
  final Color ink;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size(size, size * 34 / 30),
    painter: _MarkPainter(fill, ink),
  );
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter(this.fill, this.ink);

  final Color fill;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 30, size.height / 34);
    final receipt = Path()
      ..moveTo(3, 3)
      ..lineTo(27, 3)
      ..lineTo(27, 29);
    for (var i = 1; i <= 6; i++) {
      receipt.lineTo(27 - 4.0 * i, i.isOdd ? 26 : 29);
    }
    receipt.close();
    canvas.drawPath(receipt, Paint()..color = fill);
    final check = Path()
      ..moveTo(9.5, 15.5)
      ..lineTo(13.5, 19.5)
      ..lineTo(20.5, 11.5);
    canvas.drawPath(
      check,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 2.6,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) =>
      fill != oldDelegate.fill || ink != oldDelegate.ink;
}

class DrawerSurface extends StatelessWidget {
  const DrawerSurface({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      painter: _GrainPainter(context.palette.grain),
      child: child,
    ),
  );
}

class _GrainPainter extends CustomPainter {
  const _GrainPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final points = <Offset>[];
    for (double y = 1; y < size.height; y += 4) {
      for (double x = 1; x < size.width; x += 4) {
        points.add(Offset(x, y));
      }
    }
    canvas.drawPoints(
      PointMode.points,
      points,
      Paint()
        ..color = color
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_GrainPainter oldDelegate) => color != oldDelegate.color;
}

class DrawerPage extends StatelessWidget {
  const DrawerPage({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => DrawerSurface(
    child: ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(22, 19, 22, 28),
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ],
    ),
  );
}

class PaperPanel extends StatelessWidget {
  const PaperPanel({
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(16),
    super.key,
  });

  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Material(
    color: color ?? context.palette.panel,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: color == null
          ? BorderSide(color: context.palette.line)
          : BorderSide.none,
    ),
    clipBehavior: Clip.antiAlias,
    child: Padding(padding: padding, child: child),
  );
}

class DashedRule extends StatelessWidget {
  const DashedRule(this.color, {super.key});

  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 1,
    width: double.infinity,
    child: CustomPaint(painter: _RulePainter(color)),
  );
}

class _RulePainter extends CustomPainter {
  const _RulePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (double x = 0; x < size.width; x += 7) {
      canvas.drawLine(
        Offset(x, .5),
        Offset(math.min(x + 4, size.width), .5),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RulePainter oldDelegate) => color != oldDelegate.color;
}

class ReceiptArtwork extends StatelessWidget {
  const ReceiptArtwork({super.key});

  @override
  Widget build(BuildContext context) => const ExcludeSemantics(
    child: CustomPaint(size: Size(123, 120), painter: _ReceiptArtworkPainter()),
  );
}

class _ReceiptArtworkPainter extends CustomPainter {
  const _ReceiptArtworkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 123, size.height / 120);
    _sheet(
      canvas,
      const Offset(72, 47),
      .20,
      65,
      77,
      const Color(0xfff0ecd7),
      false,
    );
    _sheet(canvas, const Offset(53, 61), -.19, 67, 91, drawerPaper, true);
    canvas.restore();
  }

  void _sheet(
    Canvas canvas,
    Offset center,
    double angle,
    double width,
    double height,
    Color color,
    bool front,
  ) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.translate(-width / 2, -height / 2);
    final sheet = Path()
      ..lineTo(width, 0)
      ..lineTo(width, height - 3);
    for (var i = 1; i <= 10; i++) {
      sheet.lineTo(width * (10 - i) / 10, height - (i.isOdd ? 0 : 3));
    }
    sheet.close();
    canvas.drawShadow(sheet, drawerInk.withValues(alpha: .65), 5, false);
    canvas.drawPath(sheet, Paint()..color = color);
    final muted = Paint()
      ..color = const Color(0xff8b8e76)
      ..strokeWidth = 1.1;
    final ink = Paint()
      ..color = drawerInk
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(10, 13), Offset(width - 26, 13), ink);
    for (var index = 0; index < 6; index++) {
      final x = 10.0 + index * 8;
      canvas.drawLine(Offset(x, 22), Offset(x + 4, 22), muted);
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(8, 31, 39, 9),
        const Radius.circular(2),
      ),
      Paint()..color = drawerLime,
    );
    canvas.drawLine(const Offset(12, 35.5), const Offset(42, 35.5), muted);
    canvas.drawLine(const Offset(10, 48), Offset(width - 18, 48), muted);
    if (front) {
      final mark = Path()
        ..moveTo(width - 31, 65)
        ..lineTo(width - 25, 71)
        ..lineTo(width - 14, 59);
      canvas.drawPath(
        mark,
        Paint()
          ..color = const Color(0xff426929)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 2.4,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ReceiptArtworkPainter oldDelegate) => false;
}
