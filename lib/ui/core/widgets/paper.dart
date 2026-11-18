import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';

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
