import 'package:flutter/widgets.dart';

import '../../../domain/item_status.dart';
import '../../../domain/models/item.dart';
import '../theme/tokens.dart';
import '../theme/type.dart';
import 'meter.dart';
import 'paper.dart';
import 'stamp.dart';

class ItemCard extends StatefulWidget {
  const ItemCard({
    required this.summary,
    this.onTap,
    this.landStamp = false,
    this.onLanded,
    super.key,
  });

  final ItemSummary summary;
  final VoidCallback? onTap;
  final bool landStamp;
  final VoidCallback? onLanded;

  @override
  State<ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<ItemCard> {
  bool _pressed = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    final receipt = summary.item.kind == ItemKind.bill;
    final body = _PrintedCard(
      summary: summary,
      receipt: receipt,
      landStamp: widget.landStamp,
      onLanded: widget.onLanded,
    );
    final child = receipt
        ? ReceiptPaper(child: body)
        : DocumentPaper(child: body);
    final tap = widget.onTap;
    return Semantics(
      label: summary.semanticLabel,
      button: tap != null,
      onTap: tap,
      excludeSemantics: true,
      child: tap == null
          ? child
          : FocusableActionDetector(
              onShowFocusHighlight: (focus) => setState(() => _focus = focus),
              actions: {
                ActivateIntent: CallbackAction<ActivateIntent>(
                  onInvoke: (_) {
                    tap();
                    return null;
                  },
                ),
              },
              mouseCursor: SystemMouseCursors.click,
              child: GestureDetector(
                excludeFromSemantics: true,
                onTap: tap,
                onTapDown: (_) => setState(() => _pressed = true),
                onTapUp: (_) => setState(() => _pressed = false),
                onTapCancel: () => setState(() => _pressed = false),
                child: TweenAnimationBuilder<double>(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 150),
                  curve: Curves.easeOutCubic,
                  tween: Tween(end: _pressed ? -2 : 0),
                  builder: (context, lift, child) => Transform.translate(
                    offset: Offset(0, lift),
                    child: child,
                  ),
                  child: DecoratedBox(
                    position: DecorationPosition.foreground,
                    decoration: BoxDecoration(
                      border: _focus
                          ? Border.all(color: Pd.lime, width: 2)
                          : null,
                      borderRadius: BorderRadius.circular(Pd.rXs),
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
    );
  }
}

class _PrintedCard extends StatelessWidget {
  const _PrintedCard({
    required this.summary,
    required this.receipt,
    required this.landStamp,
    required this.onLanded,
  });

  final ItemSummary summary;
  final bool receipt;
  final bool landStamp;
  final VoidCallback? onLanded;

  @override
  Widget build(BuildContext context) {
    final stack = isLargeText(context);
    final stampKind = summary.stamp;
    final stamp = stampKind == null
        ? null
        : PdStamp(stampKind, land: landStamp, onLanded: onLanded);
    final rule = receipt ? const DashedRule() : const SolidRule();
    final name = Text(
      summary.item.name,
      style: PdType.cardTitle.copyWith(color: Pd.ink),
    );
    final window = summary.shown;
    final caption = PdType.label.copyWith(color: Pd.inkMuted);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          spacing: Pd.s2,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(child: Text(summary.headerType, style: caption)),
            if (summary.headerSource.isNotEmpty)
              Flexible(
                child: Text(
                  summary.headerSource,
                  textAlign: TextAlign.end,
                  maxLines: stack ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: caption,
                ),
              ),
          ],
        ),
        const SizedBox(height: Pd.s3),
        rule,
        const SizedBox(height: Pd.s3),
        if (stamp == null)
          name
        else if (stack) ...[
          name,
          const SizedBox(height: Pd.s2),
          Align(alignment: AlignmentDirectional.centerStart, child: stamp),
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: Pd.s3,
            children: [
              Expanded(child: name),
              stamp,
            ],
          ),
        const SizedBox(height: Pd.s3),
        for (final (label, value, strong) in summary.dataRows)
          _PrintedRow(label: label, value: value, strong: strong),
        const SizedBox(height: Pd.s3),
        rule,
        const SizedBox(height: Pd.s3),
        if (window != null) ...[
          _PrintedRow(
            label: window.cardLabel,
            value: window.cardValue(summary.today),
            strong: true,
            due: window.isDue(summary.today),
          ),
          const SizedBox(height: Pd.s2),
          MeterBar(
            fraction: window.usedFraction(summary.today),
            track: Pd.paperTrack,
            fill: window.isEnded(summary.today)
                ? Pd.stampExpired
                : (window.isDue(summary.today) ? Pd.stampDue : Pd.ink2),
          ),
          const SizedBox(height: Pd.s1),
        ],
        Text(
          summary.footer,
          style: PdType.footnote.copyWith(color: Pd.inkMuted),
        ),
      ],
    );
  }
}

class _PrintedRow extends StatelessWidget {
  const _PrintedRow({
    required this.label,
    required this.value,
    required this.strong,
    this.due = false,
  });

  final String label;
  final String value;
  final bool strong;
  final bool due;

  @override
  Widget build(BuildContext context) {
    final stacked = isLargeText(context);
    final keyText = Text(
      label,
      style: PdType.label.copyWith(color: Pd.inkMuted),
    );
    final valueText = Text(
      value,
      textAlign: stacked ? TextAlign.start : TextAlign.end,
      style: (strong ? PdType.dataStrong : PdType.data).copyWith(
        color: due ? Pd.dueInk : Pd.ink2,
      ),
    );
    return stacked
        ? Padding(
            padding: const EdgeInsets.only(bottom: Pd.s1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [keyText, valueText],
            ),
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            spacing: Pd.s2,
            children: [
              Flexible(child: keyText),
              Flexible(child: valueText),
            ],
          );
  }
}
