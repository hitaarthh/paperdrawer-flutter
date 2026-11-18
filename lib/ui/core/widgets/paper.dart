import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';

/// The design's one-point dot on a four-point grid.
class PaperGrain extends CustomPainter {
  const PaperGrain();

  @override
  void paint(Canvas canvas, Size size) {
    final dot = Paint()..color = Pd.hairline.withValues(alpha: 0.035);
    for (double y = 2; y < size.height; y += Pd.s1) {
      for (double x = 2; x < size.width; x += Pd.s1) {
        canvas.drawCircle(Offset(x, y), 0.5, dot);
      }
    }
  }

  @override
  bool shouldRepaint(PaperGrain oldDelegate) => false;
}

/// Paper with side notches and a dashed perforation at the stub.
class NotchedTicketPaper extends StatelessWidget {
  const NotchedTicketPaper({
    required this.stubWidth,
    required this.child,
    this.fill = Pd.paper,
    this.perforationAlpha = 0.25,
    super.key,
  });

  final double stubWidth;
  final Widget child;
  final Color fill;
  final double perforationAlpha;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _NotchedTicketPainter(
      fill: fill,
      perforation: Pd.ink.withValues(alpha: perforationAlpha),
      stubWidth: stubWidth,
    ),
    child: child,
  );
}

class _NotchedTicketPainter extends CustomPainter {
  const _NotchedTicketPainter({
    required this.fill,
    required this.perforation,
    required this.stubWidth,
  });

  final Color fill;
  final Color perforation;
  final double stubWidth;

  static const _notchRadius = 10.0;

  @override
  void paint(Canvas canvas, Size size) {
    final middle = size.height / 2;
    final ticket = Path.combine(
      PathOperation.difference,
      Path()..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(Pd.rSm),
        ),
      ),
      Path()
        ..addOval(
          Rect.fromCircle(center: Offset(0, middle), radius: _notchRadius),
        )
        ..addOval(
          Rect.fromCircle(
            center: Offset(size.width, middle),
            radius: _notchRadius,
          ),
        ),
    );
    canvas.drawPath(ticket, Paint()..color = fill);
    final dash = Paint()
      ..color = perforation
      ..strokeWidth = 2;
    for (double y = 0; y < size.height; y += Pd.s2) {
      canvas.drawLine(
        Offset(stubWidth, y),
        Offset(stubWidth, (y + Pd.s1).clamp(0, size.height)),
        dash,
      );
    }
  }

  @override
  bool shouldRepaint(_NotchedTicketPainter oldDelegate) =>
      oldDelegate.fill != fill ||
      oldDelegate.perforation != perforation ||
      oldDelegate.stubWidth != stubWidth;
}

class ReceiptPaper extends StatelessWidget {
  const ReceiptPaper({
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(Pd.s5, Pd.s5, Pd.s5, Pd.s8),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      painter: const _ReceiptPainter(),
      child: Padding(padding: padding, child: child),
    ),
  );
}

class _ReceiptPainter extends CustomPainter {
  const _ReceiptPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const pitch = Pd.s3;
    final baseline = size.height - Pd.s2;
    final paper = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, baseline);

    for (double x = size.width; x > 0; x -= pitch) {
      paper
        ..lineTo((x - pitch / 2).clamp(0, size.width), size.height)
        ..lineTo((x - pitch).clamp(0, size.width), baseline);
    }
    paper.close();
    for (final shadow in Pd.shadowPaper) {
      canvas.drawPath(paper.shift(shadow.offset), shadow.toPaint());
    }
    canvas.drawPath(paper, Paint()..color = Pd.paper);
  }

  @override
  bool shouldRepaint(_ReceiptPainter oldDelegate) => false;
}

class DocumentPaper extends StatelessWidget {
  const DocumentPaper({
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(Pd.s5, Pd.s4, Pd.s5, Pd.s5),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: DecoratedBox(
      decoration: const BoxDecoration(
        boxShadow: Pd.shadowPaper,
        borderRadius: BorderRadius.all(Radius.circular(Pd.rXs)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Pd.rXs),
        child: ColoredBox(
          color: Pd.paper2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 2, child: ColoredBox(color: Pd.ink2)),
              const SizedBox(height: 2),
              const SizedBox(height: 2, child: ColoredBox(color: Pd.ink2)),
              Padding(padding: padding, child: child),
            ],
          ),
        ),
      ),
    ),
  );
}

class DashedRule extends StatelessWidget {
  const DashedRule({this.color = Pd.paperDash, this.thickness = 1, super.key});

  final Color color;
  final double thickness;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: thickness,
    width: double.infinity,
    child: CustomPaint(painter: _Dashes(color)),
  );
}

class _Dashes extends CustomPainter {
  const _Dashes(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (double x = 0; x < size.width; x += Pd.s2) {
      canvas.drawRect(
        Rect.fromLTRB(x, 0, (x + Pd.s1).clamp(0, size.width), size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_Dashes oldDelegate) => oldDelegate.color != color;
}

class SolidRule extends StatelessWidget {
  const SolidRule({this.color = Pd.paperRule, super.key});

  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 1,
    width: double.infinity,
    child: ColoredBox(color: color),
  );
}
