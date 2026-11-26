import 'package:flutter/widgets.dart';

import '../../theme/pd_colors.dart';
import '../../theme/pd_metrics.dart';
import '../../theme/pd_theme.dart';
import 'paper.dart';

/// What a StatusLabel states. The set is closed (claims are removed, so IN
/// CLAIM and OPEN are not offered).
enum PdStatusTone {
  due,
  covered,
  ended,

  /// Neutral (`ink-2` on paper, `text` on the room).
  neutral;

  Color colorIn(PdColors colors, PdGround ground) => switch (ground) {
    PdGround.paper => switch (this) {
      PdStatusTone.due => colors.dueInk,
      PdStatusTone.covered => colors.coveredInk,
      PdStatusTone.ended => colors.endedInk,
      PdStatusTone.neutral => colors.ink2,
    },
    PdGround.room => switch (this) {
      PdStatusTone.due => colors.signal,
      PdStatusTone.covered => colors.settled,
      PdStatusTone.ended => colors.textMuted,
      PdStatusTone.neutral => colors.text,
    },
  };
}

/// A small outlined capsule in mono caps: `DUE · 2 DAYS`, `COVERED`,
/// `ENDED`. 1 pt outline in the text colour, no fill, never rotated, one per
/// card. The word carries the meaning; colour only repeats it.
///
/// [text] is caller copy, written in caps.
final class StatusLabel extends StatelessWidget {
  const StatusLabel({
    required this.text,
    required this.tone,
    this.ground = PdGround.paper,
    super.key,
  });

  final String text;
  final PdStatusTone tone;
  final PdGround ground;

  @override
  Widget build(BuildContext context) {
    final pd = context.pd;
    final color = tone.colorIn(pd.colors, ground);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: PdSize.statusLabel),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(PdRadius.pill),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: PdSpace.s2,
            vertical: PdSpace.s1 / 2,
          ),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Text(text, style: pd.type.status.copyWith(color: color)),
          ),
        ),
      ),
    );
  }
}
