import 'package:go_router/go_router.dart';
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
import '../../core/widgets/button.dart';
import '../../core/widgets/chips.dart';
import '../../core/widgets/countdown_ticket.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/item_card.dart';
import '../../core/widgets/limit_notice.dart';
import '../../core/widgets/nav.dart';
import '../../core/widgets/sheets.dart';
import '../../core/widgets/snackbar.dart';
import '../add/add_flow.dart';
import '../shell/tab_reselect.dart';
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
  late final _reselect = context.read<TabReselect>();

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
        if (mounted) context.read<VaultViewModel>().reviewOld();
      });

  void _onTabReselect() {
    if (_reselect.index != 0 || !_scroll.hasClients) return;
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

  @override
  void dispose() {
    _reselect.removeListener(_onTabReselect);
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _dismiss(VaultViewModel model, String key) async {
    try {
      await model.dismissTicket(key);
    } catch (_) {
      if (!mounted) return;
      showPdSnackbar(
        context,
        'The countdown couldn’t be dismissed. Try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<VaultViewModel>();
    final ticket = model.ticket;
    final visible = model.visible;
    return PdLargeTitleScaffold(
      title: 'Vault',
      heroTag: 'vault',
      controller: _scroll,
      trailing: ScanButton(
        key: const ValueKey('vault-scan'),
        onTap: () => AddFlow.start(context),
        onLongPress: () => AddFlow.camera(context),
      ),
      slivers: [
        if (ticket != null)
          _inset(
            SizedBox(
              key: ValueKey(model.ticketKey(ticket.$1, ticket.$2)),
              child: CountdownTicket(
                summary: ticket.$1,
                window: ticket.$2,
                onTap: () => context.push(Routes.item(ticket.$1.item.id)),
                onDismissed: () =>
                    _dismiss(model, model.ticketKey(ticket.$1, ticket.$2)),
              ),
            ),
            bottom: Pd.s4,
          ),
        SliverToBoxAdapter(
          child: PdChipRow(
            children: [
              for (final filter in VaultFilter.values)
                PdFilterChip(
                  key: ValueKey('vault-filter-${filter.name}'),
                  label: filter.label,
                  count: model.count(filter),
                  selected: model.filter == filter,
                  onTap: () => model.choose(filter),
                ),
            ],
          ),
        ),
        if (model.atLimit)
          _inset(
            LimitNotice(
              count: model.activeCount,
              onReview: model.reviewOld,
              onWaitlist: () => showPdSheet<void>(
                context,
                title: 'PaperDrawer Pro',
                subtitle: 'The Pro waitlist is opening soon.',
              ),
            ),
            top: Pd.s3,
          ),
        if (model.oldestFirst)
          _inset(
            Text(
              'OLDEST ITEMS FIRST',
              style: PdType.label.copyWith(color: Pd.textMuted),
            ),
            top: Pd.s4,
          ),
        if (model.activeCount == 0)
          _inset(
            DashedTile(
              title: 'Your drawer is empty',
              body: 'Scan your first bill. We’ll read the dates.',
              action: PdButton.primary(
                key: const ValueKey('scan-first-bill'),
                label: 'Scan a bill',
                onPressed: () => AddFlow.start(context),
              ),
            ),
            top: Pd.s4,
          )
        else if (visible.isEmpty)
          _inset(
            DashedTile(
              title: switch (model.filter) {
                VaultFilter.due => 'Nothing is due',
                VaultFilter.inClaim => 'No items in a claim',
                VaultFilter.covered => 'No items with active cover',
                VaultFilter.expired => 'No expired items',
                VaultFilter.all => 'Your drawer is empty',
              },
              body: 'Choose All to see everything in your drawer.',
              action: PdButton.text(
                label: 'Show all items',
                onPressed: () => model.choose(VaultFilter.all),
              ),
            ),
            top: Pd.s4,
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(Pd.margin, Pd.s4, Pd.margin, 0),
            sliver: SliverList.builder(
              itemCount: visible.length,
              itemBuilder: (context, index) {
                final summary = visible[index];
                final id = summary.item.id;
                return Padding(
                  key: ValueKey(id),
                  padding: const EdgeInsets.only(bottom: Pd.s3),
                  child: ItemCard(
                    key: ValueKey('vault-item-$id'),
                    summary: summary,
                    onTap: () => context.push(Routes.item(id)),
                    landStamp: model.shouldLand(id),
                    onLanded: () => model.landed(id),
                  ),
                );
              },
            ),
          ),
        if (model.activeCount >= baseItemWarnAt && !model.atLimit)
          _inset(
            LimitFootnote(left: baseItemLimit - model.activeCount),
            top: Pd.s2,
          ),
      ],
    );
  }

  Widget _inset(Widget child, {double top = 0, double bottom = 0}) =>
      SliverPadding(
        padding: EdgeInsets.fromLTRB(Pd.margin, top, Pd.margin, bottom),
        sliver: SliverToBoxAdapter(child: child),
      );
}
