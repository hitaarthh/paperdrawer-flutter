import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../domain/formats.dart';
import '../../../domain/ladders.dart';
import '../../../domain/models/claim.dart';
import '../theme/tokens.dart';
import '../theme/type.dart';
import 'paper.dart';

class ClaimLadder extends StatelessWidget {
  const ClaimLadder({required this.claim, required this.today, super.key});

  final Claim claim;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final steps = ladderFor(claim.type);
    final recommended = recommendedStepFor(claim, today);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            'THE STEPS · ${claim.type.caps}',
            style: PdType.label.copyWith(color: Pd.textMuted),
          ),
        ),
        const SizedBox(height: Pd.s2),
        for (final (index, step) in steps.indexed)
          _LadderRung(
            number: index + 1,
            title: stepTitle(claim.type, index),
            guidance: index == claim.step && recommended != null
                ? 'Waiting since ${shortDate(claim.waitingSince)}.'
                : step.guidance,
            state: switch (index) {
              _
                  when index < claim.step ||
                      (index == claim.step && !claim.isOpen) =>
                _RungState.done,
              _ when index == claim.step => _RungState.current,
              _ when index == recommended => _RungState.recommended,
              _ => _RungState.upcoming,
            },
            noReplyDays: index == claim.step && recommended != null
                ? claim.waitingDays(today)
                : null,
          ),
      ],
    );
  }
}

enum _RungState { done, current, recommended, upcoming }

class _LadderRung extends StatelessWidget {
  const _LadderRung({
    required this.number,
    required this.title,
    required this.guidance,
    required this.state,
    required this.noReplyDays,
  });

  static const _dot = Pd.s6 + Pd.s1;

  final int number;
  final String title;
  final String guidance;
  final _RungState state;
  final int? noReplyDays;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      _RungState.done => Pd.settled,
      _RungState.current => Pd.signal,
      _RungState.recommended => Pd.lime,
      _RungState.upcoming => null,
    };
    final status = switch ((state, noReplyDays)) {
      (_RungState.current, final int days) => 'NO REPLY · ${daysCaps(days)}',
      (_RungState.current, _) => 'YOU ARE HERE',
      (_RungState.recommended, _) => 'RECOMMENDED NEXT',
      _ => null,
    };
    return Semantics(
      label: 'Step $number${state == _RungState.done ? ', done' : ''}',
      child: Column(
        children: [
          const SolidRule(color: Pd.hairline),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Pd.s3),
            child: Row(
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
                    child: state == _RungState.done
                        ? const Icon(
                            LucideIcons.check,
                            color: Pd.onLime,
                            size: Pd.iconSm,
                          )
                        : FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              number.toString().padLeft(2, '0'),
                              style: PdType.monoButton.copyWith(
                                color: color == null ? Pd.textMuted : Pd.onLime,
                              ),
                            ),
                          ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: Pd.s1,
                    children: [
                      if (status != null)
                        Text(
                          status,
                          style: PdType.label.copyWith(color: color),
                        ),
                      Text(title, style: PdType.bodyStrong),
                      Text(
                        guidance,
                        style: PdType.footnote.copyWith(color: Pd.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
