import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/vault_controller.dart';
import '../data/vault_record.dart';
import '../theme/drawer_theme.dart';
import 'design.dart';
import 'edit_record_page.dart';
import 'record_page.dart';

IconData kindIcon(RecordKind kind) => switch (kind) {
  RecordKind.receipt => Icons.receipt_long_outlined,
  RecordKind.policy => Icons.shield_outlined,
  RecordKind.document => Icons.description_outlined,
};

class VaultPage extends StatefulWidget {
  const VaultPage({super.key});

  @override
  State<VaultPage> createState() => _VaultPageState();
}

class _VaultPageState extends State<VaultPage> {
  String _query = '';
  RecordKind? _filter;

  @override
  Widget build(BuildContext context) {
    final records = context.watch<VaultController>().active.toList(
      growable: false,
    );
    final colors = context.palette;
    final query = _query.trim().toLowerCase();
    final visible = records
        .where((record) {
          final draft = record.draft;
          return (_filter == null || draft.kind == _filter) &&
              (query.isEmpty ||
                  [
                    draft.title,
                    draft.source,
                    draft.notes,
                    draft.kind.label,
                  ].any((value) => value.toLowerCase().contains(query)));
        })
        .toList(growable: false);

    final today = civilDate(DateTime.now());
    final due = records.where((record) {
      final deadline = record.draft.deadline;
      return deadline != null && !deadline.isBefore(today);
    }).toList()..sort((a, b) => a.draft.deadline!.compareTo(b.draft.deadline!));

    return DrawerSurface(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final gutter = math.max(22.0, (constraints.maxWidth - 520) / 2);
          return CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(gutter, 22, gutter, 14),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.lock_outline,
                            color: colors.marker,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'ON THIS DEVICE',
                            style: monoLabel(colors.marker),
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      Text('Your vault', style: displayStyle(colors.text, 49)),
                      const SizedBox(height: 9),
                      Text(
                        'Receipts, policies and important papers.',
                        style: TextStyle(
                          color: colors.muted,
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                      if (records.isEmpty) ...[
                        const SizedBox(height: 22),
                        const _WelcomeTicket(),
                        const SizedBox(height: 24),
                        Text('OR ADD AN ITEM', style: monoLabel(colors.muted)),
                        const SizedBox(height: 10),
                        for (final kind in [
                          RecordKind.policy,
                          RecordKind.document,
                        ])
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _Starter(kind: kind),
                          ),
                      ] else ...[
                        if (due.isNotEmpty) ...[
                          const SizedBox(height: 22),
                          _DueTicket(record: due.first, today: today),
                        ],
                        const SizedBox(height: 18),
                        TextField(
                          key: const ValueKey('search-vault'),
                          onChanged: (value) => setState(() => _query = value),
                          autocorrect: false,
                          textInputAction: TextInputAction.search,
                          decoration: const InputDecoration(
                            hintText: 'Search your vault',
                            prefixIcon: Icon(Icons.search, size: 21),
                          ),
                        ),
                        const SizedBox(height: 9),
                        Wrap(
                          spacing: 7,
                          children: [
                            for (final kind in [null, ...RecordKind.values])
                              ChoiceChip(
                                label: Text(kind?.plural ?? 'All'),
                                selected: _filter == kind,
                                onSelected: (_) =>
                                    setState(() => _filter = kind),
                                showCheckmark: false,
                              ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        Text(
                          visible.isEmpty
                              ? 'NO MATCHES'
                              : '${visible.length} ${visible.length == 1 ? 'ITEM' : 'ITEMS'}',
                          style: monoLabel(colors.muted),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 20),
                sliver: SliverList.builder(
                  itemCount: visible.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: RecordTile(record: visible[index]),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _WelcomeTicket extends StatelessWidget {
  const _WelcomeTicket();

  @override
  Widget build(BuildContext context) => PaperPanel(
    color: drawerLime,
    padding: const EdgeInsets.fromLTRB(19, 13, 19, 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final headline = Text(
              'Add the last thing you bought.',
              style: displayStyle(drawerInk, 30),
            );
            if (constraints.maxWidth < 250 ||
                MediaQuery.textScalerOf(context).scale(30) > 42) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: headline,
              );
            }
            return Row(
              children: [
                Expanded(child: headline),
                const ReceiptArtwork(),
              ],
            );
          },
        ),
        const DashedRule(Color(0xff78902c)),
        const SizedBox(height: 12),
        const Text(
          'Keep the receipt and its warranty date together so you can find them when you need them.',
          style: TextStyle(color: drawerInk, height: 1.4),
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: drawerInk,
              foregroundColor: drawerLime,
            ),
            icon: const Icon(Icons.document_scanner_outlined, size: 18),
            label: const Text('Add your first receipt'),
            onPressed: () => showAddEntry(context, kind: RecordKind.receipt),
          ),
        ),
      ],
    ),
  );
}

class _Starter extends StatelessWidget {
  const _Starter({required this.kind});

  final RecordKind kind;

  @override
  Widget build(BuildContext context) => Material(
    color: context.palette.panel,
    shape: RoundedRectangleBorder(
      side: BorderSide(color: context.palette.line),
      borderRadius: BorderRadius.circular(10),
    ),
    child: ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      leading: Icon(kindIcon(kind), size: 22, color: context.palette.marker),
      title: Text(
        kind == RecordKind.policy
            ? 'An insurance policy'
            : 'An important document',
      ),
      trailing: const Icon(Icons.arrow_forward, size: 18),
      onTap: () => showAddEntry(context, kind: kind),
    ),
  );
}

class _DueTicket extends StatelessWidget {
  const _DueTicket({required this.record, required this.today});

  final VaultRecord record;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final draft = record.draft;
    final days = draft.deadline!.difference(today).inDays;
    return Material(
      color: drawerOrange,
      borderRadius: BorderRadius.circular(12),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: () => showRecord(context, record.id),
        leading: Icon(Icons.timelapse_outlined, color: drawerInk, size: 25),
        title: Text(draft.title, style: displayStyle(drawerInk, 20)),
        subtitle: Text(
          '${draft.kind.deadlineLabel.toUpperCase()} · ${days == 0 ? 'TODAY' : 'IN $days ${days == 1 ? 'DAY' : 'DAYS'}'}',
          style: monoLabel(drawerInk, size: 10),
        ),
        trailing: const Icon(Icons.arrow_forward, color: drawerInk),
      ),
    );
  }
}

class RecordTile extends StatelessWidget {
  const RecordTile({required this.record, super.key});

  final VaultRecord record;

  @override
  Widget build(BuildContext context) {
    final draft = record.draft;
    final colors = context.palette;
    final subtitle = draft.source.isEmpty
        ? draft.kind.label
        : '${draft.kind.label} · ${draft.source}';

    return Material(
      color: colors.panel,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colors.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 2),
        leading: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: colors.marker.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(kindIcon(draft.kind), color: colors.marker, size: 22),
        ),
        title: Text(
          draft.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: displayStyle(colors.text, 19),
        ),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: () => showRecord(context, record.id),
      ),
    );
  }
}
