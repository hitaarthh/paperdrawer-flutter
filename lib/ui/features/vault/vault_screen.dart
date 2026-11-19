import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/item_repository.dart';
import '../../../data/services/today.dart';
import '../../../domain/item_status.dart';
import '../../../routing/router.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/type.dart';
import '../../core/widgets/brand_bar.dart';
import '../../core/widgets/button.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/item_card.dart';
import '../add/add_flow.dart';
import '../reminders/reminder_inbox.dart';
import '../shell/tab_reselect.dart';
import 'vault_empty.dart';
import 'vault_header.dart';
import 'vault_view_model.dart';

class VaultScreen extends StatelessWidget {
  const VaultScreen({
    this.reviewOld = false,
    this.showDue = false,
    this.addedId,
    super.key,
  });

  final bool reviewOld;
  final bool showDue;
  final String? addedId;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (context) =>
        VaultViewModel(context.read<ItemRepository>(), context.read<Today>()),
    child: _VaultView(reviewOld: reviewOld, showDue: showDue, addedId: addedId),
  );
}

class _VaultView extends StatefulWidget {
  const _VaultView({
    required this.reviewOld,
    required this.showDue,
    required this.addedId,
  });

  final bool reviewOld;
  final bool showDue;
  final String? addedId;

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
    _applyDestinationOnNextFrame();
  }

  @override
  void didUpdateWidget(covariant _VaultView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reviewOld != oldWidget.reviewOld ||
        widget.showDue != oldWidget.showDue ||
        widget.addedId != oldWidget.addedId) {
      _applyDestinationOnNextFrame();
    }
  }

  void _applyDestinationOnNextFrame() {
    if (!widget.reviewOld && !widget.showDue && widget.addedId == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final model = context.read<VaultViewModel>();
      if (widget.reviewOld) {
        _reviewOld();
      } else if (widget.showDue) {
        _clearSearch(model);
        model.choose(VaultFilter.due);
      } else if (widget.addedId case final id?) {
        _clearSearch(model);
        model.showRecent(id);
      }
      _toTop();
    });
  }

  void _reviewOld() {
    _search.clear();
    context.read<VaultViewModel>().reviewOld();
  }

  void _onTabReselect() {
    if (_reselect.index == 1) _toTop();
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
                  trailing: const DrawerNotificationButton(fromDrawer: true),
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
                      _inset(const VaultHeader(), top: Pd.s3),
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
                          VaultEmpty(onAdd: () => AddFlow.manual(context)),
                          top: Pd.s6,
                        )
                      else
                        ..._full(model),
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

  List<Widget> _full(VaultViewModel model) {
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
          DashedTile(
            title: 'Drawer is full',
            body: 'Archive an older file to make room.',
            action: PdButton.text(
              label: 'Review older files',
              onPressed: _reviewOld,
            ),
          ),
          top: Pd.s4,
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
        VaultFilter.covered => 'No items with active cover',
        VaultFilter.expired => 'No expired files',
        VaultFilter.undated => 'Every file has a tracked date',
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
