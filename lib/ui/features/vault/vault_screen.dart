import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/claim_repository.dart';
import '../../../data/repositories/item_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../data/services/today.dart';
import '../../../domain/item_status.dart';
import '../../../routing/router.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/type.dart';
import '../../core/widgets/brand_bar.dart';
import '../../core/widgets/button.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/item_card.dart';
import '../../core/widgets/limit_notice.dart';
import '../../core/widgets/sheets.dart';
import '../../core/widgets/snackbar.dart';
import '../add/add_flow.dart';
import '../shell/tab_reselect.dart';
import 'vault_due_next.dart';
import 'vault_empty.dart';
import 'vault_header.dart';
import 'vault_view_model.dart';

class VaultScreen extends StatelessWidget {
  const VaultScreen({this.reviewOld = false, super.key});

  final bool reviewOld;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (context) => VaultViewModel(
      context.read<ItemRepository>(),
      context.read<ClaimRepository>(),
      context.read<SettingsRepository>(),
      context.read<Today>(),
    ),
    child: _VaultView(reviewOld: reviewOld),
  );
}

class _VaultView extends StatefulWidget {
  const _VaultView({required this.reviewOld});

  final bool reviewOld;

  @override
  State<_VaultView> createState() => _VaultViewState();
}

class _VaultViewState extends State<_VaultView> {
  final _scroll = ScrollController();
  final _search = TextEditingController();
  late final _reselect = context.read<TabReselect>();
  bool _scrolled = false;

  @override
  void initState() {
    super.initState();
    _reselect.addListener(_onTabReselect);
    if (widget.reviewOld) _reviewOnNextFrame();
  }

  @override
  void didUpdateWidget(covariant _VaultView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reviewOld && !oldWidget.reviewOld) _reviewOnNextFrame();
  }

  void _reviewOnNextFrame() =>
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _reviewOld();
      });

  void _reviewOld() {
    _search.clear();
    context.read<VaultViewModel>().reviewOld();
  }

  void _onTabReselect() {
    if (_reselect.index == 0) _toTop();
  }

  void _toTop() {
    if (!_scroll.hasClients) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _scroll.jumpTo(0);
    } else {
      _scroll.animateTo(
        0,
        duration: Pd.sheetDuration,
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _clearSearch(VaultViewModel model) {
    _search.clear();
    model.search('');
  }

  @override
  void dispose() {
    _reselect.removeListener(_onTabReselect);
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  void _open(VaultTicketData ticket) {
    if (ticket.itemId case final id?) {
      context.push(Routes.item(id));
    } else if (ticket.claimId case final id?) {
      context.go(Routes.claim(id));
    }
  }

  Future<void> _hide(VaultViewModel model, VaultTicketData ticket) async {
    final hide = await showPdActions<bool>(
      context,
      title: ticket.title,
      message: 'It comes back tomorrow if it still needs you.',
      actions: const [PdAction(label: 'Hide for today', value: true)],
    );
    if (hide != true || !mounted) return;
    try {
      await model.dismissTicket(ticket.key);
    } catch (_) {
      if (!mounted) return;
      showPdSnackbar(context, 'The countdown couldn’t be hidden. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<VaultViewModel>();
    final empty = model.activeCount == 0;
    return Scaffold(
      backgroundColor: Pd.bg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Pd.maxContent),
          child: Column(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  border: _scrolled
                      ? const Border(bottom: BorderSide(color: Pd.hairline))
                      : null,
                ),
                child: PdBrandBar(
                  onMarkTap: _toTop,
                  trailing: GestureDetector(
                    onLongPress: () => AddFlow.camera(context),
                    child: PdBrandAction(
                      key: const ValueKey('vault-scan'),
                      label: 'Scan or add',
                      icon: LucideIcons.scanLine,
                      onPressed: () => AddFlow.start(context),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification.depth != 0 ||
                        notification.metrics.axis != Axis.vertical) {
                      return false;
                    }
                    final scrolled = notification.metrics.extentBefore > 0;
                    if (scrolled != _scrolled) {
                      setState(() => _scrolled = scrolled);
                    }
                    return false;
                  },
                  child: CustomScrollView(
                    controller: _scroll,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    slivers: [
                      _inset(VaultHeader(kicker: model.kicker), top: Pd.s3),
                      if (model.justAdded case final recent?)
                        _inset(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            spacing: Pd.s3,
                            children: [
                              Text(
                                'JUST ADDED',
                                style: PdType.label.copyWith(color: Pd.lime),
                              ),
                              _card(model, recent),
                            ],
                          ),
                          top: Pd.s6,
                        ),
                      if (empty)
                        _inset(
                          VaultEmpty(
                            onScan: () => AddFlow.camera(context),
                            onStart: (_) => AddFlow.start(context),
                          ),
                          top: Pd.s6,
                        )
                      else
                        ..._full(model),
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

  List<Widget> _full(VaultViewModel model) {
    final tickets = model.query.isEmpty
        ? model.tickets
        : const <VaultTicketData>[];
    final recent = model.justAdded?.item.id;
    final visible = model.visible
        .where((item) => item.item.id != recent)
        .toList();
    return [
      _inset(
        VaultSearchField(
          controller: _search,
          onChanged: model.search,
          count: model.activeCount,
        ),
        top: Pd.s6,
      ),
      if (model.atLimit)
        _inset(
          LimitNotice(
            count: model.activeCount,
            onReview: _reviewOld,
            onWaitlist: () => showPdSheet<void>(
              context,
              title: 'Paper Drawer Pro',
              subtitle: 'The Pro waitlist is opening soon.',
            ),
          ),
          top: Pd.s4,
        ),
      if (tickets.isNotEmpty)
        SliverPadding(
          padding: const EdgeInsets.only(top: Pd.s6),
          sliver: SliverToBoxAdapter(
            child: VaultDueNext(
              tickets: tickets,
              onOpen: _open,
              onHide: (ticket) => _hide(model, ticket),
            ),
          ),
        ),
      SliverPadding(
        padding: const EdgeInsets.only(top: Pd.s6),
        sliver: SliverToBoxAdapter(
          child: VaultFilterTabs(
            selected: model.filter,
            count: model.count,
            onSelect: model.choose,
          ),
        ),
      ),
      _inset(
        Text(
          model.oldestFirst
              ? 'OLDEST ITEMS FIRST'
              : 'SORTED BY WHAT’S DUE FIRST',
          style: PdType.label.copyWith(color: Pd.textMuted),
        ),
        top: Pd.s3,
      ),
      if (visible.isEmpty && recent == null)
        _inset(_noMatches(model), top: Pd.s6)
      else if (visible.isNotEmpty)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(Pd.margin, Pd.s6, Pd.margin, 0),
          sliver: SliverList.builder(
            itemCount: visible.length,
            itemBuilder: (context, index) {
              final summary = visible[index];
              final id = summary.item.id;
              return Padding(
                key: ValueKey(id),
                padding: const EdgeInsets.only(bottom: Pd.s5),
                child: _card(model, summary),
              );
            },
          ),
        ),
      if (model.activeCount >= baseItemWarnAt && !model.atLimit)
        _inset(
          LimitFootnote(left: baseItemLimit - model.activeCount),
          top: Pd.s2,
        ),
    ];
  }

  Widget _card(VaultViewModel model, ItemSummary summary) {
    final id = summary.item.id;
    return ItemCard(
      key: ValueKey('vault-item-$id'),
      summary: summary,
      onTap: () => context.push(Routes.item(id)),
      landStamp: model.shouldLand(id),
      onLanded: () => model.landed(id),
    );
  }

  Widget _noMatches(VaultViewModel model) {
    if (model.query.isNotEmpty && model.count(VaultFilter.all) == 0) {
      return DashedTile(
        title: 'Nothing matches “${model.query.trim()}”',
        body: 'Try a name, a store or a policy number.',
        action: PdButton.text(
          key: const ValueKey('vault-clear-search'),
          label: 'Clear search',
          onPressed: () => _clearSearch(model),
        ),
      );
    }
    return DashedTile(
      title: switch (model.filter) {
        VaultFilter.due => 'Nothing is due soon',
        VaultFilter.inClaim => 'No items in a claim',
        VaultFilter.covered => 'No items with active cover',
        VaultFilter.expired => 'Nothing has ended',
        VaultFilter.all => 'Your drawer is empty',
      },
      body: 'Choose All to see everything in your drawer.',
      action: PdButton.text(
        label: 'Show all items',
        onPressed: () => model.choose(VaultFilter.all),
      ),
    );
  }

  Widget _inset(Widget child, {double top = 0, double bottom = 0}) =>
      SliverPadding(
        padding: EdgeInsets.fromLTRB(Pd.margin, top, Pd.margin, bottom),
        sliver: SliverToBoxAdapter(child: child),
      );
}
