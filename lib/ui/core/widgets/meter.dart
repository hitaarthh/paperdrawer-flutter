import 'package:flutter/widgets.dart';

import '../../../domain/item_status.dart';
import '../theme/tokens.dart';
import '../theme/type.dart';

class MeterBar extends StatelessWidget {
  const MeterBar({
    this.fraction = 0,
    this.fill = Pd.lime,
    this.track = Pd.surface3,
    this.height = Pd.s2,
    super.key,
  });

  final double fraction;
  final Color fill;
  final Color track;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: double.infinity,
    child: ColoredBox(
      color: track,
      child: FractionallySizedBox(
        alignment: AlignmentDirectional.centerStart,
        widthFactor: fraction.clamp(0, 1),
        child: ColoredBox(color: fill),
      ),
    ),
  );
}

class PdMeter extends StatelessWidget {
  const PdMeter({
    required this.window,
    required this.today,
    this.onPaper = false,
    super.key,
  });

  final CoverWindow window;
  final DateTime today;
  final bool onPaper;

  @override
  Widget build(BuildContext context) {
    final fill = _fill;
    final labelColor = onPaper ? Pd.inkMuted : Pd.text2;
    final valueColor = onPaper && window.isDue(today) ? Pd.dueInk : fill;
    final title = Text(window.label, style: PdType.label.copyWith(color: labelColor));
    final value = Text(
      window.meterValue(today),
      textAlign: isLargeText(context) ? TextAlign.start : TextAlign.end,
      style: PdType.dataStrong.copyWith(color: valueColor),
    );
    return Semantics(
      label: '${window.fact(today)}, ${window.meterFooter(today)}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isLargeText(context)) ...[
            title,
            value,
          ] else
            Row(
              spacing: Pd.s2,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(child: title),
                Flexible(child: value),
              ],
            ),
          const SizedBox(height: Pd.s2),
          MeterBar(
            fraction: window.usedFraction(today),
            track: onPaper ? Pd.paperTrack : Pd.surface3,
            fill: fill,
          ),
          const SizedBox(height: Pd.s1),
          Text(
            window.meterFooter(today),
            style: PdType.footnote.copyWith(color: onPaper ? Pd.inkMuted : Pd.textMuted),
          ),
        ],
      ),
    );
  }

  Color get _fill {
    if (window.isEnded(today)) return onPaper ? Pd.stampExpired : Pd.textMuted;
    if (window.isDue(today)) return onPaper ? Pd.stampDue : Pd.signal;
    return onPaper ? Pd.ink2 : Pd.lime;
  }
}
