import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../../domain/formats.dart';
import '../../../domain/item_status.dart';
import '../../../domain/models/claim.dart';
import '../../../domain/models/item.dart';
import '../theme/tokens.dart';
import '../theme/type.dart';
import 'button.dart';
import 'chips.dart';
import 'claim_ladder.dart';
import 'countdown_ticket.dart';
import 'empty_state.dart';
import 'icons.dart';
import 'item_card.dart';
import 'limit_notice.dart';
import 'list_row.dart';
import 'meter.dart';
import 'nav.dart';
import 'paper.dart';
import 'sheets.dart';
import 'snackbar.dart';
import 'stamp.dart';
import 'tab_bar.dart';
import 'text_field.dart';

/// Standalone component fixture for visual QA, with deterministic dates.
class WidgetGallery extends StatefulWidget {
  const WidgetGallery({super.key});

  @override
  State<WidgetGallery> createState() => _WidgetGalleryState();
}

class _WidgetGalleryState extends State<WidgetGallery> {
  final _today = DateTime(2026, 11, 18);
  final _name = TextEditingController(text: 'Wireless earbuds');
  int _tab = 0;
  bool _remind = true;
  DateTime? _date;
  ItemKind _kind = ItemKind.bill;
  VaultFilter _filter = VaultFilter.all;

  late final _bill = ItemSummary.of(
    Item(
      id: 'gallery-bill',
      draft: ItemDraft(
        kind: ItemKind.bill,
        name: 'Wireless earbuds',
        source: 'Croma',
        amountMinor: 299900,
        startsOn: DateTime(2026, 11, 10),
        returnUntil: DateTime(2026, 11, 20),
        coverUntil: DateTime(2027, 11, 10),
      ),
      createdAt: _today,
    ),
    _today,
  );

  late final _policy = ItemSummary.of(
    Item(
      id: 'gallery-policy',
      draft: ItemDraft(
        kind: ItemKind.policy,
        name: 'Family health policy',
        subtype: 'Health',
        source: 'Shield General Insurance',
        reference: 'SH-216914',
        amountMinor: 1199000,
        startsOn: DateTime(2025, 12, 10),
        coverUntil: DateTime(2026, 12, 10),
      ),
      createdAt: _today,
    ),
    _today,
  );

  late final _claim = Claim(
    id: 'gallery-claim',
    itemLabel: 'Laptop',
    type: ClaimType.repair,
    want: ClaimWant.repair,
    problem: 'The laptop shuts down as soon as it is unplugged.',
    reference: 'LT-88213',
    openedOn: DateTime(2026, 11, 4),
    step: 1,
    stepSince: _today,
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _notify() => showPdSnackbar(
    context,
    'Saved to your drawer',
    success: true,
    action: 'Undo',
    onAction: () {},
  );

  void _showAdd() => showPdSheet<String>(
    context,
    title: 'Add to your drawer',
    subtitle: 'Choose how to add a bill or other paper.',
    options: const [
      PdSheetOption(
        icon: null,
        glyph: PdGlyph.scan,
        title: 'Scan with camera',
        description: 'Take photos of one or more pages.',
        value: 'scan',
        recommended: true,
      ),
      PdSheetOption(
        icon: LucideIcons.fileUp,
        title: 'Upload a photo or PDF',
        description: 'Choose a file from your device.',
        value: 'upload',
      ),
      PdSheetOption(
        icon: LucideIcons.pencil,
        title: 'Type it in',
        description: 'Add the details yourself.',
        value: 'manual',
      ),
    ],
  );

  Future<void> _chooseDate() async {
    final date = await showPdDatePicker(context, initial: _date ?? _today);
    if (!mounted || date == null) return;
    setState(() => _date = date);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: PdLargeTitleScaffold(
      title: 'Gallery',
      trailing: ScanButton(onTap: _showAdd),
      slivers: [
        SliverToBoxAdapter(
          child: PdChipRow(
            children: [
              for (final filter in VaultFilter.values)
                PdFilterChip(
                  label: filter.label,
                  count: filter == VaultFilter.all ? 2 : 1,
                  selected: _filter == filter,
                  onTap: () => setState(() => _filter = filter),
                ),
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(Pd.margin),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: Pd.s4,
              children: [
                CountdownTicket(
                  summary: _bill,
                  window: _bill.shown!,
                  onTap: _notify,
                  onDismissed: () {},
                ),
                ItemCard(summary: _bill, onTap: _notify),
                ItemCard(summary: _policy, onTap: _notify),
                PdMeter(window: _policy.shown!, today: _today),
                ClaimLadder(claim: _claim, today: _today),
                const Wrap(
                  spacing: Pd.s3,
                  runSpacing: Pd.s2,
                  children: [
                    PdStamp(StampKind.waiting),
                    PdStamp(StampKind.escalate),
                    PdStamp(StampKind.settled),
                  ],
                ),
                ReceiptPaper(
                  child: Wrap(
                    spacing: Pd.s2,
                    children: [
                      for (final kind in ItemKind.values)
                        PdChoiceChip(
                          label: kind.label,
                          selected: _kind == kind,
                          onTap: () => setState(() => _kind = kind),
                        ),
                    ],
                  ),
                ),
                DocumentPaper(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: Pd.s2,
                    children: [
                      Text(
                        'Dear support team,',
                        style: PdType.body.copyWith(color: Pd.ink),
                      ),
                      const SolidRule(),
                      PdButton.onPaper(
                        label: 'Copy message',
                        onPressed: _notify,
                      ),
                    ],
                  ),
                ),
                PdTextField(
                  label: 'Product',
                  controller: _name,
                  readFromBill: true,
                  validator: (value) => value.isEmpty ? 'Add a name.' : null,
                ),
                PdFieldButton(
                  label: 'Purchase date',
                  value: _date == null ? '' : longDate(_date!),
                  onTap: _chooseDate,
                ),
                PdListGroup(
                  header: 'Reminders',
                  children: [
                    PdListRow(
                      title: 'Reminders',
                      trailing: PdSwitch(
                        value: _remind,
                        onChanged: (value) => setState(() => _remind = value),
                      ),
                    ),
                    PdListRow(
                      title: 'Remind me',
                      value: '7 days before',
                      chevron: true,
                      onTap: _chooseDate,
                    ),
                  ],
                ),
                DashedTile(
                  title: 'Your drawer is empty',
                  body: 'Scan your first bill. We’ll read the dates.',
                  action: PdButton.primary(
                    label: 'Scan a bill',
                    onPressed: _showAdd,
                  ),
                ),
                LimitNotice(count: 25, onReview: _notify, onWaitlist: _notify),
                const LimitFootnote(left: 5),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: PdNavIcon(
                    icon: const Icon(LucideIcons.ellipsis),
                    semanticLabel: 'More actions',
                    onTap: () => showPdActions<bool>(
                      context,
                      actions: const [PdAction(label: 'Edit', value: true)],
                    ),
                  ),
                ),
                PdButton.secondary(
                  label: 'Export everything',
                  onPressed: _notify,
                ),
                PdButton.text(
                  label: 'Show confirmation',
                  onPressed: () => showPdConfirm(
                    context,
                    title: 'Delete this item?',
                    message: 'Its attachments will also be deleted.',
                    confirmLabel: 'Delete',
                    destructive: true,
                  ),
                ),
                const Center(child: PaperDrawerMark()),
              ],
            ),
          ),
        ),
      ],
    ),
    bottomNavigationBar: PdTabBar(
      currentIndex: _tab,
      onTap: (index) => setState(() => _tab = index),
      claimsBadge: 2,
    ),
  );
}
