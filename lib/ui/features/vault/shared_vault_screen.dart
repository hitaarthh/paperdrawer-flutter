import 'package:go_router/go_router.dart';
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
import '../account/shared_session.dart';
import '../add/add_sheet.dart';
import '../add/shared_add_flow.dart';
import 'vault_empty.dart';
import 'vault_header.dart';

class SharedVaultScreen extends StatefulWidget {
  const SharedVaultScreen({this.showDue = false, super.key});

  final bool showDue;

  @override
  State<SharedVaultScreen> createState() => _SharedVaultScreenState();
}

class _SharedVaultScreenState extends State<SharedVaultScreen> {
  final _search = TextEditingController();
  late VaultFilter _filter = widget.showDue ? VaultFilter.due : VaultFilter.all;

  @override
  void didUpdateWidget(covariant SharedVaultScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showDue && !oldWidget.showDue) {
      _search.clear();
      _filter = VaultFilter.due;
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
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
    return Scaffold(
      backgroundColor: Pd.bg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Pd.maxContent),
          child: Column(
            children: [
              const PdBrandBar(),
              Expanded(
                child: RefreshIndicator.adaptive(
                  onRefresh: session.refresh,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    slivers: [
                      _inset(const VaultHeader(), top: Pd.s3),
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
                            onScan: () => openSharedAdd(
                              context,
                              vault,
                              const AddSheetChoice(
                                AddSheetAction.camera,
                                ItemKind.bill,
                              ),
                            ),
                            onStart: (kind) => openSharedAdd(
                              context,
                              vault,
                              AddSheetChoice(AddSheetAction.manual, kind),
                            ),
                          ),
                        ),
                      if (vault != null && summaries.isNotEmpty)
                        ..._full(summaries),
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: Pd.s12 + MediaQuery.paddingOf(context).bottom,
                        ),
                      ),
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

  List<Widget> _full(List<ItemSummary> summaries) {
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
    return [
      _inset(
        VaultSearchField(
          controller: _search,
          count: summaries.length,
          onChanged: (_) => setState(() {}),
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

  Widget _inset(Widget child, {double top = Pd.s6}) => SliverPadding(
    padding: EdgeInsets.fromLTRB(Pd.margin, top, Pd.margin, 0),
    sliver: SliverToBoxAdapter(child: child),
  );
}
