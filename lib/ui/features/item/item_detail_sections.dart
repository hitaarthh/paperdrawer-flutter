import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:native_liquid_glass/native_liquid_glass.dart';

import '../../../domain/formats.dart';
import '../../../domain/item_status.dart';
import '../../../domain/models/item.dart';
import '../../core/widgets/glass.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/type.dart';
import '../../core/widgets/meter.dart';
import '../../core/widgets/paper.dart';
import '../../core/widgets/vault_ticket.dart';

List<(String, String)> itemRecord(ItemSummary summary) {
  final draft = summary.d;
  return [
    if (draft.startsOn case final start?)
      (
        draft.kind == ItemKind.bill ? 'PURCHASE DATE' : 'START DATE',
        longDate(start),
      ),
    if (draft.amountMinor case final amount?)
      (draft.kind.amountLabel, money(amount, draft.currency)),
    if (draft.reference.isNotEmpty)
      (draft.kind.referenceLabel, draft.reference),
    if (draft.source.isNotEmpty) (draft.kind.sourceLabel, draft.source),
    if (draft.serialNumber.isNotEmpty) ('SERIAL NUMBER', draft.serialNumber),
  ];
}

class ItemDetailActions extends StatelessWidget {
  const ItemDetailActions({
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    if (NativeLiquidGlassUtils.supportsLiquidGlass) {
      return PdNativeGlassTouch(
        child: LiquidGlassToolbar(
          height: Pd.tapMin,
          width: 2 * Pd.tapMin + 2 * Pd.s1,
          itemSpacing: Pd.tapMin - Pd.s5,
          padding: const EdgeInsets.symmetric(horizontal: Pd.s1),
          items: [
            LiquidGlassToolbarItem(
              id: 'edit',
              label: 'Edit item',
              icon: const NativeLiquidGlassIcon.sfSymbol('pencil'),
              iconSize: Pd.s5,
              enabled: onEdit != null,
            ),
            LiquidGlassToolbarItem(
              id: 'delete',
              label: 'Delete item',
              icon: const NativeLiquidGlassIcon.sfSymbol('trash'),
              iconSize: Pd.s5,
              enabled: onDelete != null,
            ),
          ],
          onItemTapped: (id) {
            if (id == 'edit') onEdit?.call();
            if (id == 'delete') onDelete?.call();
          },
        ),
      );
    }
    return PdGlassSurface(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Pd.s1),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PdGlassIcon(
              key: const ValueKey('item-edit'),
              icon: const Icon(LucideIcons.pencil),
              label: 'Edit item',
              systemIcon: 'pencil',
              onPressed: onEdit,
              inSurface: false,
            ),
            PdGlassIcon(
              key: const ValueKey('item-delete'),
              icon: const Icon(LucideIcons.trash2),
              label: 'Delete item',
              systemIcon: 'trash',
              onPressed: onDelete,
              inSurface: false,
            ),
          ],
        ),
      ),
    );
  }
}

class ItemDeadlineTicket extends StatelessWidget {
  const ItemDeadlineTicket(this.summary, {super.key});

  final ItemSummary summary;

  @override
  Widget build(BuildContext context) {
    final window = summary.shown;
    if (window == null) return const SizedBox.shrink();
    final left = window.daysLeft(summary.today);
    final number = switch (left) {
      < 0 => 'ENDED',
      0 => 'TODAY',
      _ => left.toString().padLeft(2, '0'),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: Pd.s5),
      child: VaultTicket(
        number: number,
        unit: left > 0 ? (left == 1 ? 'DAY' : 'DAYS') : null,
        kicker: window.ticketKicker,
        title: longDate(window.end),
        body: window.fact(summary.today),
        tone: left >= 0 && left <= 7
            ? VaultTicketTone.signal
            : VaultTicketTone.paper,
        semanticLabel:
            '${window.ticketKicker}, ${longDate(window.end)}, ${window.fact(summary.today)}',
      ),
    );
  }
}

class ItemOriginalPaper extends StatelessWidget {
  const ItemOriginalPaper(
    this.summary, {
    this.fileFormat,
    required this.rows,
    this.original,
    super.key,
  });

  final ItemSummary summary;
  final String? fileFormat;
  final List<(String, String)> rows;
  final Widget? original;

  @override
  Widget build(BuildContext context) {
    final caption = PdType.label.copyWith(color: Pd.inkMuted);
    final facts = [('TYPE', summary.item.kind.label), ...rows];
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Pd.s3,
      children: [
        Row(
          spacing: Pd.s2,
          children: [
            Expanded(
              child: Text(
                original == null ? 'ON RECORD' : 'ORIGINAL FILE',
                style: caption,
              ),
            ),
            if (fileFormat case final format?) Text(format, style: caption),
          ],
        ),
        const DashedRule(),
        if (original case final preview?) ...[preview, const DashedRule()],
        for (final (label, value) in facts)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: Pd.s3,
            children: [
              Expanded(child: Text(label.toUpperCase(), style: caption)),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: PdType.callout.copyWith(color: Pd.ink),
                ),
              ),
            ],
          ),
      ],
    );
    return summary.item.kind == ItemKind.bill
        ? ReceiptPaper(child: content)
        : DocumentPaper(child: content);
  }
}

class ItemCoverage extends StatelessWidget {
  const ItemCoverage(this.summary, {super.key});

  final ItemSummary summary;

  @override
  Widget build(BuildContext context) {
    if (summary.windows.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: Pd.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Pd.s3,
        children: [
          Text('Coverage', style: PdType.title2),
          for (final window in summary.windows)
            DocumentPaper(
              child: PdMeter(
                window: window,
                today: summary.today,
                onPaper: true,
              ),
            ),
        ],
      ),
    );
  }
}
