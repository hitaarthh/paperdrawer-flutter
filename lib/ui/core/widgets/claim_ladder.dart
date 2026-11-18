import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../domain/ladders.dart';
import '../../../domain/models/claim.dart';
import '../theme/tokens.dart';
import '../theme/type.dart';

class ClaimLadder extends StatelessWidget {
  const ClaimLadder({required this.claim, required this.today, super.key});

  final Claim claim;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final steps = ladderFor(claim.type);
    final headerStyle = PdType.label.copyWith(color: Pd.textMuted);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Pd.surface2,
        borderRadius: BorderRadius.circular(Pd.rSm),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Pd.s5, Pd.s5, Pd.s5, Pd.s2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              spacing: Pd.s2,
              children: [
                Flexible(
                  child: Text(
                    '${claim.type.caps} · ESCALATION',
                    style: headerStyle,
                  ),
                ),
                Flexible(
                  child: Text(
                    claim.itemLabel.toUpperCase(),
                    textAlign: TextAlign.end,
                    style: headerStyle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Pd.s4),
            for (final (index, step) in steps.indexed)
              _LadderRung(
                number: index + 1,
                title: stepTitle(claim.type, index),
                guidance:
                    index == claim.step &&
                        claim.status(today) == ClaimStatus.escalate &&
                        index < steps.length - 1
                    ? 'You can move to the next step.'
                    : step.guidance,
                result:
                    index < claim.step || (index == claim.step && !claim.isOpen)
                    ? _RungState.done
                    : (index == claim.step
                          ? _RungState.current
                          : _RungState.upcoming),
                day: claim.day(today),
                last: index == steps.length - 1,
              ),
          ],
        ),
      ),
    );
  }
}

enum _RungState { done, current, upcoming }

class _LadderRung extends StatelessWidget {
  const _LadderRung({
    required this.number,
    required this.title,
    required this.guidance,
    required this.result,
    required this.day,
    required this.last,
  });

  static const _dot = Pd.s6 + Pd.s1;

  final int number;
  final String title;
  final String guidance;
  final _RungState result;
  final int day;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final color = switch (result) {
      _RungState.done => Pd.settled,
      _RungState.current => Pd.signal,
      _RungState.upcoming => null,
    };
    return Semantics(
      label: 'Step $number${result == _RungState.done ? ', done' : ''}',
      child: Stack(
        children: [
          if (!last)
            const Positioned(
              left: _dot / 2 - 1,
              top: _dot + Pd.s1,
              bottom: Pd.s1,
              width: 2,
              child: ColoredBox(color: Pd.line),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: Pd.s3,
            children: [
              ExcludeSemantics(
                child: Container(
                  width: _dot,
                  height: _dot,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: color == null
                        ? Border.all(color: Pd.line, width: 2)
                        : null,
                  ),
                  child: result == _RungState.done
                      ? const Icon(
                          LucideIcons.check,
                          color: Pd.onLime,
                          size: Pd.iconSm,
                        )
                      : Text(
                          '$number',
                          textScaler: MediaQuery.textScalerOf(context)
                              .clamp(maxScaleFactor: 1.5),
                          style: PdType.dataStrong.copyWith(
                            color: result == _RungState.current
                                ? Pd.onLime
                                : Pd.textMuted,
                          ),
                        ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: Pd.s4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      if (result == _RungState.current)
                        Text(
                          'YOU ARE HERE · DAY $day',
                          style: PdType.label.copyWith(color: Pd.signal),
                        ),
                      Text(
                        title,
                        style: PdType.bodyStrong.copyWith(
                          color: switch (result) {
                            _RungState.done => Pd.textMuted,
                            _RungState.current => Pd.text,
                            _RungState.upcoming => Pd.text2,
                          },
                        ),
                      ),
                      Text(
                        guidance,
                        style: PdType.footnote.copyWith(color: Pd.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
