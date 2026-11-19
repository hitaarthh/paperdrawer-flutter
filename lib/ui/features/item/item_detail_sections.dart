import 'package:cupertino_ui/cupertino_ui.dart';

import '../../../domain/formats.dart';
import '../../../domain/item_status.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/type.dart';
import '../../core/widgets/list_row.dart';
import '../../core/widgets/meter.dart';
import '../../core/widgets/paper.dart';
import '../../core/widgets/vault_ticket.dart';

String itemDetailKicker(ItemSummary summary, {String? category}) {
  final draft = summary.d;
  return [
    if (summary.item.isArchived) 'Archived',
    category ?? (draft.subtype.isEmpty ? draft.kind.label : draft.subtype),
    if (draft.source.isNotEmpty) draft.source,
    if (draft.startsOn case final start?) shortDate(start),
  ].join(' · ').toUpperCase();
}

List<(String, String)> itemRecord(ItemSummary summary) {
  final draft = summary.d;
  return [
    if (draft.amountMinor case final amount?)
      (draft.kind.amountLabel, money(amount, draft.currency)),
    if (draft.reference.isNotEmpty)
      (draft.kind.referenceLabel, draft.reference),
    if (draft.source.isNotEmpty) (draft.kind.sourceLabel, draft.source),
    if (draft.serialNumber.isNotEmpty) ('SERIAL NUMBER', draft.serialNumber),
  ];
}

class ItemReturnTicket extends StatelessWidget {
  const ItemReturnTicket(this.summary, {super.key});

  final ItemSummary summary;

  @override
  Widget build(BuildContext context) {
    final window = summary.windows
        .where((window) => window.type == WindowType.returnWindow)
        .firstOrNull;
    if (window == null || summary.item.isArchived) {
      return const SizedBox.shrink();
    }
    final left = window.daysLeft(summary.today);
    if (left < 0 || left > ticketWithinDays) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: Pd.s5),
      child: VaultTicket(
        number: left == 0 ? 'TODAY' : left.toString().padLeft(2, '0'),
        unit: left == 0
            ? null
            : left == 1
            ? 'DAY'
            : 'DAYS',
        kicker: window.ticketKicker,
        title: 'Return by ${shortDate(window.end)}',
        body: 'Keep your original handy if you need to make a return.',
        tone: VaultTicketTone.signal,
        semanticLabel: window.fact(summary.today),
      ),
    );
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

class ItemClaimKit extends StatelessWidget {
  const ItemClaimKit({
    required this.description,
    required this.actions,
    super.key,
  });

  final String description;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Pd.s6),
    child: Container(
      padding: const EdgeInsets.all(Pd.s4),
      decoration: BoxDecoration(
        color: Pd.surface2,
        borderRadius: BorderRadius.circular(Pd.rSm),
        border: Border.all(color: Pd.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Pd.s3,
        children: [
          Text('Claim kit', style: PdType.title2),
          Text(
            description,
            style: PdType.callout.copyWith(color: Pd.textMuted),
          ),
          ...actions,
        ],
      ),
    ),
  );
}

class ItemClaimHistoryEmpty extends StatelessWidget {
  const ItemClaimHistoryEmpty({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Pd.s6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: Pd.s2,
      children: [
        Text('CLAIMS ON THIS ITEM', style: PdType.label.copyWith(color: Pd.textMuted)),
        Text(
          'No claims yet. Open one to keep a record of calls, emails and visits alongside your saved documents.',
          style: PdType.callout.copyWith(color: Pd.textMuted),
        ),
      ],
    ),
  );
}

class ItemRecord extends StatelessWidget {
  const ItemRecord(this.rows, {super.key});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) => rows.isEmpty
      ? const SizedBox.shrink()
      : PdListGroup(
          header: 'On record',
          children: [
            for (final (label, value) in rows)
              PdListRow(title: label, value: value),
          ],
        );
}
