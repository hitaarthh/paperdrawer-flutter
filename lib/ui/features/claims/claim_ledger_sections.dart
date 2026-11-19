import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../../domain/formats.dart';
import '../../../domain/item_status.dart';
import '../../../domain/models/ledger.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/type.dart';
import '../../core/widgets/button.dart';
import '../../core/widgets/paper.dart';
import '../../core/widgets/stamp.dart';

class LedgerStatus extends StatelessWidget {
  const LedgerStatus({
    required this.isOpen,
    required this.day,
    required this.entries,
    super.key,
  });

  final bool isOpen;
  final int day;
  final List<LedgerEntry> entries;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: Pd.s3,
    runSpacing: Pd.s2,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Semantics(
        label: isOpen ? 'Open' : 'Settled',
        child: PdStamp(
          isOpen ? StampKind.escalate : StampKind.settled,
          compactLabel: isOpen ? 'OPEN' : 'SETTLED',
        ),
      ),
      Text(
        [
          '${entries.length} ${entries.length == 1 ? 'ENTRY' : 'ENTRIES'}',
          'DAY $day',
          if (entries.firstOrNull case final entry?)
            'LAST UPDATE ${shortDate(entry.date).toUpperCase()}',
        ].join(' · '),
        style: PdType.label.copyWith(color: Pd.text2),
      ),
    ],
  );
}

class LedgerReminder extends StatelessWidget {
  const LedgerReminder({required this.value, required this.onChange, super.key});

  final String? value;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Pd.surface2,
      border: Border.all(color: Pd.hairline),
      borderRadius: BorderRadius.circular(Pd.rSm),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(Pd.s3, Pd.s2, Pd.s1, Pd.s2),
      child: Row(
        spacing: Pd.s2,
        children: [
          const Icon(LucideIcons.bell, size: Pd.iconSm, color: Pd.lime),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: Pd.s1,
              children: [
                Text('YOUR FOLLOW-UP REMINDER', style: PdType.label.copyWith(color: Pd.textMuted)),
                Text(value ?? 'No reminder set', style: PdType.bodyStrong),
              ],
            ),
          ),
          PdButton.text(
            key: const ValueKey('ledger-change-follow-up'),
            label: value == null ? 'Set' : 'Change',
            monospaced: true,
            onPressed: onChange,
          ),
        ],
      ),
    ),
  );
}

class LedgerPaper extends StatelessWidget {
  const LedgerPaper(this.entries, {super.key});

  final List<LedgerEntry> entries;

  @override
  Widget build(BuildContext context) {
    final label = PdType.label.copyWith(color: Pd.inkMuted);
    return DocumentPaper(
      padding: const EdgeInsets.fromLTRB(Pd.s4, Pd.s4, Pd.s4, Pd.s2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: Pd.s3,
            runSpacing: Pd.s1,
            children: [
              Semantics(header: true, child: Text('CLAIM LEDGER', style: label)),
              if (entries.isNotEmpty) Text('NEWEST FIRST', style: label),
            ],
          ),
          const SizedBox(height: Pd.s2),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Pd.s3),
              child: Text('No entries yet.', style: PdType.body.copyWith(color: Pd.ink)),
            ),
          for (final entry in entries)
            _LedgerLine(key: ValueKey('ledger-line-${entry.id}'), entry: entry),
        ],
      ),
    );
  }
}

class _LedgerLine extends StatelessWidget {
  const _LedgerLine({required this.entry, super.key});
  final LedgerEntry entry;

  @override
  Widget build(BuildContext context) {
    final label = PdType.label.copyWith(color: Pd.inkMuted);
    final text = PdType.footnote.copyWith(color: Pd.ink2);
    return Column(
      children: [
        const SolidRule(color: Pd.paperRule),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: Pd.s3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: Pd.s3,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: Pd.s1,
                  children: [
                    Text(shortDate(entry.date).toUpperCase(), style: label.copyWith(color: Pd.ink)),
                    Text(entry.kind.label.toUpperCase(), style: label),
                  ],
                ),
              ),
              Expanded(
                flex: 7,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: Pd.s1,
                  children: [
                    Text(entry.text, style: PdType.bodyStrong.copyWith(color: Pd.ink)),
                    if (entry.details.isNotEmpty) Text(entry.details, style: text),
                    if (entry.reference.isNotEmpty) Text('REF ${entry.reference}', style: label.copyWith(color: Pd.ink)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
