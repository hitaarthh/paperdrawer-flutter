import 'package:flutter/widgets.dart';

import '../../theme/pd_dynamic_type.dart';
import '../../theme/pd_metrics.dart';
import '../../theme/pd_theme.dart';
import 'meter_flat.dart';
import 'paper.dart';

/// How big the number is.
enum DeadlineCardSize {
  /// `figure` (40): Home.
  card,

  /// `figure-xl` (56): item detail.
  detail,
}

/// The countdown for one upcoming date, number first: a 64 pt number column
/// with a `paper-rule` hairline on its right, then the eyebrow, the item
/// name and one `callout` line; the meter spans the bottom.
///
/// All copy is the caller's (view model getters): [count] is "02" or "TODAY"
/// ([unit] then null), [due] (7 days or fewer) turns the number and meter
/// `due-ink`. At accessibility text sizes the number moves above the title.
final class DeadlineCard extends StatelessWidget {
  const DeadlineCard({
    required this.count,
    required this.eyebrow,
    required this.title,
    required this.detail,
    required this.remaining,
    required this.due,
    required this.semanticLabel,
    this.unit = 'DAYS',
    this.paper = PdPaperKind.bill,
    this.size = DeadlineCardSize.card,
    this.onPressed,
    super.key,
  });

  /// "02", or "TODAY" (with [unit] null).
  final String count;

  /// "DAYS" under the number; null when [count] is "TODAY".
  final String? unit;

  /// `RETURN WINDOW`, `POLICY RENEWAL`, `WARRANTY`.
  final String eyebrow;
  final String title;

  /// "Closes Fri, 27 Nov · Croma".
  final String detail;

  /// Fraction of the window left (0–1).
  final double remaining;
  final bool due;

  /// One element for VoiceOver: "Boat Airdopes 141, return window closes
  /// Friday, 2 days left".
  final String semanticLabel;
  final PdPaperKind paper;
  final DeadlineCardSize size;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final stacked = PdDynamicType.isAccessibilitySize(context);
    return PdPaper(
      kind: paper,
      onPressed: onPressed,
      semanticLabel: semanticLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (stacked) ...[
            _number(context),
            const SizedBox(height: PdSpace.s2),
            _texts(context),
          ] else
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _numberColumn(context),
                  const SizedBox(width: PdSpace.s4),
                  Expanded(child: _texts(context)),
                ],
              ),
            ),
          const SizedBox(height: PdSpace.s3 + PdSpace.s1 / 2),
          PdMeterBar(remaining: remaining, due: due),
        ],
      ),
    );
  }

  Widget _numberColumn(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minWidth: PdSize.deadlineNumberColumn),
    child: DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: context.pd.colors.paperRule),
        ),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(end: PdSpace.s4),
        child: _number(context),
      ),
    ),
  );

  Widget _number(BuildContext context) {
    final pd = context.pd;
    final color = due ? pd.colors.dueInk : pd.colors.ink;
    final unit = this.unit;
    final figure = switch ((size, unit)) {
      (_, null) => pd.type.figureSm,
      (DeadlineCardSize.card, _) => pd.type.figure,
      (DeadlineCardSize.detail, _) => pd.type.figureXl,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(count, style: figure.copyWith(color: color)),
        if (unit != null) ...[
          const SizedBox(height: PdSpace.s1 / 2),
          Text(unit, style: pd.type.label.copyWith(color: color)),
        ],
      ],
    );
  }

  Widget _texts(BuildContext context) {
    final pd = context.pd;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(eyebrow, style: pd.type.label.copyWith(color: pd.colors.inkMuted)),
        const SizedBox(height: PdSpace.s1),
        Text(title, style: pd.type.cardTitle.copyWith(color: pd.colors.ink)),
        const SizedBox(height: PdSpace.s1),
        Text(detail, style: pd.type.callout.copyWith(color: pd.colors.inkMuted)),
      ],
    );
  }
}
