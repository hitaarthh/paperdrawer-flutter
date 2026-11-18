import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../domain/item_status.dart';
import '../../../domain/models/item.dart';
import '../../../domain/models/shared_vault.dart';
import '../../../routing/router.dart' show Routes;
import '../../core/theme/tokens.dart';
import '../../core/theme/type.dart';
import '../../core/widgets/brand_bar.dart';
import '../../core/widgets/button.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/item_card.dart';
import '../../core/widgets/sheets.dart';
import '../../core/widgets/snackbar.dart';
import '../account/shared_session.dart';
import '../add/add_sheet.dart';
import 'vault_due_next.dart';
import 'vault_empty.dart';
import 'vault_header.dart';
import 'vault_tickets.dart';

class SharedVaultScreen extends StatefulWidget {
  const SharedVaultScreen({super.key});

  @override
  State<SharedVaultScreen> createState() => _SharedVaultScreenState();
}

class _SharedVaultScreenState extends State<SharedVaultScreen> {
  final _search = TextEditingController();
  final _hidden = <String>{};
  VaultFilter _filter = VaultFilter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _add(SharedSession session, SharedVault vault) async {
    final choice = await showAddSheet(
      context,
      used: vault.items.length,
      shared: true,
      onBasePlan: vault.onBasePlan,
    );
    if (!mounted || choice == null) return;
    await _openAdd(
      session,
      choice.kind,
      manual: choice.action == AddSheetAction.manual,
    );
  }

  Future<void> _openAdd(
    SharedSession session,
    ItemKind kind, {
    bool manual = false,
  }) async {
    final type = kind == ItemKind.agreement ? 'other' : kind.name;
    final path = switch ((manual, kind)) {
      (false, _) => '/add?type=$type',
      (true, ItemKind.bill) => '/bills/new',
      (true, _) => '/documents/new?type=$type',
    };
    try {
      await session.openWeb(path);
    } catch (_) {
      if (!mounted) return;
      showPdSnackbar(context, 'Couldn’t open Paper Drawer web.');
    }
  }

  void _openTicket(VaultTicketData ticket) {
    if (ticket.itemId case final id?) {
      context.push(Routes.item(id));
    } else if (ticket.claimId case final id?) {
      context.go(Routes.claim(id));
    }
  }

  Future<void> _hideTicket(VaultTicketData ticket) async {
    final hide = await showPdActions<bool>(
      context,
      title: ticket.title,
      actions: const [PdAction(label: 'Hide for today', value: true)],
    );
    if (!mounted || hide != true) return;
    setState(() => _hidden.add(ticket.key));
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SharedSession>();
    final vault = session.vault;
    final today = session.today.value;
    final claims =
        vault?.claims.where((claim) => claim.settled == null).toList() ??
        const <SharedClaim>[];
    final openItemIds = claims.map((claim) => claim.itemId).toSet();
    final summaries = [
      for (final entry in vault?.items ?? const <SharedItem>[])
        ItemSummary.of(
          entry.item,
          today,
          hasOpenClaim: openItemIds.contains(entry.item.id),
        ),
    ]..sort((a, b) => a.sortRank.compareTo(b.sortRank));
    final due = summaries.where(VaultFilter.due.matches).length;
    final count = summaries.length;
    final kicker = [
      '${count.toString().padLeft(3, '0')} ${count == 1 ? 'ITEM' : 'ITEMS'}',
      due == 0 ? 'NOTHING DUE' : '$due DUE SOON',
      if (claims.isNotEmpty)
        '${claims.length} OPEN ${claims.length == 1 ? 'CLAIM' : 'CLAIMS'}',
    ].join(' · ');
    return Scaffold(
      backgroundColor: Pd.bg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Pd.maxContent),
          child: Column(
            children: [
              PdBrandBar(
                trailing: vault == null
                    ? null
                    : PdBrandAction(
                        key: const ValueKey('shared-vault-add'),
                        label: 'Scan or add',
                        icon: LucideIcons.scanLine,
                        onPressed: () => _add(session, vault),
                      ),
              ),
              Expanded(
                child: RefreshIndicator.adaptive(
                  onRefresh: session.refresh,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    slivers: [
                      _inset(
                        VaultHeader(
                          kicker: vault == null ? 'SHARED VAULT' : kicker,
                        ),
                        top: Pd.s3,
                      ),
                      if (session.failed)
                        _inset(
                          DashedTile(
                            title: 'Couldn’t refresh Paper Drawer',
                            body: 'Check your connection and try again.',
                            action: PdButton.text(
                              label: 'Try again',
                              onPressed: session.refresh,
                            ),
                          ),
                        ),
                      if (vault == null && session.loading)
                        _inset(
                          Text('Loading your drawer…', style: PdType.callout),
                        ),
                      if (vault != null && summaries.isEmpty)
                        _inset(
                          VaultEmpty(
                            shared: true,
                            onScan: () => _openAdd(session, ItemKind.bill),
                            onStart: (kind) =>
                                _openAdd(session, kind, manual: true),
                          ),
                        ),
                      if (vault != null && summaries.isNotEmpty)
                        ..._full(vault, summaries, claims, today),
                      const SliverToBoxAdapter(child: SizedBox(height: Pd.s12)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _full(
    SharedVault vault,
    List<ItemSummary> summaries,
    List<SharedClaim> claims,
    DateTime today,
  ) {
    final words = _search.text
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty);
    final searched = summaries.where((summary) {
      final draft = summary.d;
      final text = [
        draft.name,
        draft.source,
        draft.subtype,
        draft.reference,
        draft.kind.label,
      ].join(' ').toLowerCase();
      return words.every(text.contains);
    }).toList();
    final visible = searched.where(_filter.matches).toList();
    final tickets = words.isEmpty
        ? _tickets(summaries, claims, today)
        : const <VaultTicketData>[];
    return [
      _inset(
        VaultSearchField(
          controller: _search,
          count: vault.onBasePlan ? summaries.length : null,
          onChanged: (_) => setState(() {}),
        ),
      ),
      if (tickets.isNotEmpty)
        SliverPadding(
          padding: const EdgeInsets.only(top: Pd.s6),
          sliver: SliverToBoxAdapter(
            child: VaultDueNext(
              tickets: tickets,
              onOpen: _openTicket,
              onHide: _hideTicket,
            ),
          ),
        ),
      SliverPadding(
        padding: const EdgeInsets.only(top: Pd.s6),
        sliver: SliverToBoxAdapter(
          child: VaultFilterTabs(
            selected: _filter,
            count: (filter) => searched.where(filter.matches).length,
            onSelect: (filter) => setState(() => _filter = filter),
          ),
        ),
      ),
      _inset(
        Text(
          'SORTED BY WHAT’S DUE FIRST',
          style: PdType.label.copyWith(color: Pd.textMuted),
        ),
        top: Pd.s3,
      ),
      if (visible.isEmpty)
        _inset(
          DashedTile(
            title: 'No matching items',
            body: 'Try a different search or filter.',
            action: PdButton.text(
              label: 'Show all items',
              onPressed: () {
                _search.clear();
                setState(() => _filter = VaultFilter.all);
              },
            ),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(Pd.margin, Pd.s6, Pd.margin, 0),
          sliver: SliverList.builder(
            itemCount: visible.length,
            itemBuilder: (context, index) {
              final summary = visible[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: Pd.s5),
                child: ItemCard(
                  key: ValueKey('shared-item-${summary.item.id}'),
                  summary: summary,
                  onTap: () => context.push(Routes.item(summary.item.id)),
                ),
              );
            },
          ),
        ),
    ];
  }

  List<VaultTicketData> _tickets(
    List<ItemSummary> summaries,
    List<SharedClaim> claims,
    DateTime today,
  ) {
    final windows = [
      for (final summary in summaries)
        if (summary.next case final window?
            when window.daysLeft(today) <= ticketWithinDays)
          (summary, window),
    ]..sort((a, b) => a.$2.end.compareTo(b.$2.end));
    final tickets = [
      for (final (summary, window) in windows)
        VaultTicketData.window(
          summary,
          window,
          '$today/${summary.item.id}/${window.type.name}/${window.end}',
        ),
      for (final claim in claims)
        if (claim.needsAction) VaultTicketData.sharedClaim(claim, today),
    ].where((ticket) => !_hidden.contains(ticket.key)).take(5).toList();
    if (tickets.isNotEmpty && tickets.first.itemId != null) {
      tickets[0] = tickets.first.asMostUrgent();
    }
    return tickets;
  }

  Widget _inset(Widget child, {double top = Pd.s6}) => SliverPadding(
    padding: EdgeInsets.fromLTRB(Pd.margin, top, Pd.margin, 0),
    sliver: SliverToBoxAdapter(child: child),
  );
}
