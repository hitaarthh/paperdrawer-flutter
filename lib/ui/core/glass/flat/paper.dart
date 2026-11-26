import 'package:flutter/widgets.dart';

import '../../theme/pd_colors.dart';
import '../../theme/pd_metrics.dart';
import '../../theme/pd_theme.dart';
import '../pd_pressable.dart';

/// Where a flat component sits: on paper or on the room.
enum PdGround { paper, room }

/// Which paper: bills and receipts on `paper`, documents (policy, vehicle,
/// agreement) on `paper-2`.
enum PdPaperKind {
  bill,
  document;

  Color groundIn(PdColors colors) => switch (this) {
    PdPaperKind.bill => colors.paper,
    PdPaperKind.document => colors.paper2,
  };
}

/// The paper ground for content: `radius-md` continuous corners, `space-4`
/// padding, no shadow at rest, no torn edges, notches or stamps. With
/// [onPressed] the whole card is one button that scales to `pressed-scale`
/// with `shadow-paper-pressed` (no scale with Reduce Motion).
final class PdPaper extends StatelessWidget {
  const PdPaper({
    required this.child,
    this.kind = PdPaperKind.bill,
    this.onPressed,
    this.onLongPress,
    this.semanticLabel,
    this.padding = const EdgeInsets.all(PdSpace.s4),
    super.key,
  }) : assert(
         onPressed == null || semanticLabel != null,
         'A tappable card needs one semantic label.',
       );

  final Widget child;
  final PdPaperKind kind;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;

  /// Read as one element when the card is tappable.
  final String? semanticLabel;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.pd.colors;
    final card = DecoratedBox(
      decoration: ShapeDecoration(
        color: kind.groundIn(colors),
        shape: PdRadius.continuous(PdRadius.md),
      ),
      child: Padding(padding: padding, child: child),
    );
    final label = semanticLabel;
    if (onPressed == null || label == null) {
      return label == null
          ? card
          : Semantics(
              container: true,
              label: label,
              excludeSemantics: true,
              child: card,
            );
    }
    return PdPressable(
      semanticLabel: label,
      onPressed: onPressed,
      onLongPress: onLongPress,
      focusRadius: PdRadius.md,
      focusGround: PdFocusGround.room,
      pressedShadow: PdShadows.paperPressed(colors),
      child: card,
    );
  }
}
