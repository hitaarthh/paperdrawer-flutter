import 'package:flutter/widgets.dart';

import '../../theme/pd_dynamic_type.dart';
import '../../theme/pd_metrics.dart';
import '../../theme/pd_theme.dart';
import 'paper.dart';

/// The 4 pt bar alone. Fill = time remaining, so it empties toward the
/// deadline. Decorative for VoiceOver (the count text is read instead).
final class PdMeterBar extends StatelessWidget {
  const PdMeterBar({
    required this.remaining,
    this.due = false,
    this.ground = PdGround.paper,
    super.key,
  });

  /// 0 (ended) to 1 (whole window left).
  final double remaining;
  final bool due;
  final PdGround ground;

  @override
  Widget build(BuildContext context) {
    final colors = context.pd.colors;
    final (track, fill) = switch (ground) {
      PdGround.paper => (colors.paperTrack, due ? colors.dueInk : colors.ink2),
      PdGround.room => (colors.surface3, due ? colors.signalFill : colors.text),
    };
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(PdRadius.pill),
        child: SizedBox(
          height: PdSize.meter,
          child: ColoredBox(
            color: track,
            child: FractionallySizedBox(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: remaining.clamp(0, 1).toDouble(),
              heightFactor: 1,
              child: ColoredBox(color: fill),
            ),
          ),
        ),
      ),
    );
  }
}

/// A meter with its window name and exact count above it: `RETURN` ·
/// "2 of 10 days left". Never a percentage. When [due], the fill and the
/// count turn `due-ink` (paper) / `signal` (room).
///
/// At accessibility text sizes the name sits above the count.
final class PdMeterFlat extends StatelessWidget {
  const PdMeterFlat({
    required this.label,
    required this.countText,
    required this.remaining,
    this.due = false,
    this.ground = PdGround.paper,
    super.key,
  });

  /// Window name in caps: `RETURN`, `WARRANTY`, `COMPRESSOR`.
  final String label;

  /// "2 of 10 days left".
  final String countText;
  final double remaining;
  final bool due;
  final PdGround ground;

  @override
  Widget build(BuildContext context) {
    final pd = context.pd;
    final c = pd.colors;
    final (labelColor, countColor) = switch (ground) {
      PdGround.paper => (c.inkMuted, due ? c.dueInk : c.ink2),
      PdGround.room => (c.textMuted, due ? c.signal : c.text),
    };
    final name = Text(label, style: pd.type.label.copyWith(color: labelColor));
    final count = Text(
      countText,
      textAlign: TextAlign.end,
      style: pd.type.data.copyWith(color: countColor),
    );
    final header = PdDynamicType.isAccessibilitySize(context)
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [name, count],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(child: name),
              const SizedBox(width: PdSpace.s3),
              Expanded(child: count),
            ],
          );
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          header,
          const SizedBox(height: PdSpace.s1 + PdSpace.s1 / 2),
          PdMeterBar(remaining: remaining, due: due, ground: ground),
        ],
      ),
    );
  }
}
