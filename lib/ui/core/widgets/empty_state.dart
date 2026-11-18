import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';
import '../theme/type.dart';

class DashedTile extends StatelessWidget {
  const DashedTile({
    required this.title,
    required this.body,
    this.action,
    super.key,
  });

  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: const _DashedBorder(),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: Pd.s5, vertical: Pd.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: PdType.title2,
            ),
          ),
          const SizedBox(height: Pd.s2),
          Text(
            body,
            textAlign: TextAlign.center,
            style: PdType.callout.copyWith(color: Pd.textMuted),
          ),
          if (action case final button?) ...[
            const SizedBox(height: Pd.s5),
            Center(child: button),
          ],
        ],
      ),
    ),
  );
}

class _DashedBorder extends CustomPainter {
  const _DashedBorder();

  @override
  void paint(Canvas canvas, Size size) {
    final shape = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(0.5),
          const Radius.circular(Pd.rSm),
        ),
      );
    final stroke = Paint()
      ..color = Pd.line
      ..style = PaintingStyle.stroke;
    for (final contour in shape.computeMetrics()) {
      for (double start = 0; start < contour.length; start += Pd.s2) {
        canvas.drawPath(
          contour.extractPath(start, (start + Pd.s1).clamp(0, contour.length)),
          stroke,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder oldDelegate) => false;
}
