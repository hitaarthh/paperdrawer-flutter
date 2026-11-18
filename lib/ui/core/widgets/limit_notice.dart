import 'package:cupertino_ui/cupertino_ui.dart';

import '../../../domain/item_status.dart';
import '../theme/tokens.dart';
import '../theme/type.dart';
import 'button.dart';
import 'meter.dart';

class LimitNotice extends StatelessWidget {
  const LimitNotice({
    required this.count,
    required this.onReview,
    required this.onWaitlist,
    super.key,
  });

  final int count;
  final VoidCallback onReview;
  final VoidCallback onWaitlist;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Pd.signalTint,
      borderRadius: BorderRadius.circular(Pd.rSm),
    ),
    child: Padding(
      padding: const EdgeInsets.all(Pd.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Pd.s2,
        children: [
          Text(
            '$count OF $baseItemLimit ITEMS · BASE PLAN',
            style: PdType.label.copyWith(color: Pd.signal),
          ),
          MeterBar(
            fraction: count / baseItemLimit,
            fill: Pd.signal,
            track: Pd.surface3,
            height: Pd.rSm,
          ),
          Text(
            'Nothing is deleted and reminders keep running. Archive an old item to add a new one, or join the Pro waitlist.',
            style: PdType.callout.copyWith(color: Pd.signalSoft),
          ),
          Wrap(
            spacing: Pd.s2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              PdButton.secondary(
                label: 'Review old items',
                onPressed: onReview,
              ),
              CupertinoButton(
                minimumSize: const Size.square(Pd.tapMin),
                focusColor: Pd.lime,
                pressedOpacity: 0.7,
                padding: const EdgeInsets.symmetric(
                  horizontal: Pd.s2,
                  vertical: Pd.s1,
                ),
                onPressed: onWaitlist,
                child: Text(
                  'JOIN PRO WAITLIST',
                  style: PdType.monoButton.copyWith(color: Pd.lime),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class LimitFootnote extends StatelessWidget {
  const LimitFootnote({required this.left, super.key});

  final int left;

  @override
  Widget build(BuildContext context) => Text(
    '$left ${left == 1 ? 'item' : 'items'} left on Base',
    style: PdType.footnote.copyWith(color: Pd.textMuted),
  );
}
