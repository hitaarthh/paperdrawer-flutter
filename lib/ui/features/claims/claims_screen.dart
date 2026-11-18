import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../domain/item_status.dart';
import '../../../domain/models/claim.dart';
import '../../../routing/router.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/type.dart';
import '../../core/widgets/button.dart';
import '../../core/widgets/chips.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/nav.dart';
import '../../core/widgets/stamp.dart';
import '../add/add_flow.dart';
import '../shell/tab_reselect.dart';
import 'claims_view_model.dart';

class ClaimsScreen extends StatefulWidget {
  const ClaimsScreen({super.key});

  @override
  State<ClaimsScreen> createState() => _ClaimsScreenState();
}

class _ClaimsScreenState extends State<ClaimsScreen> {
  final _scroll = ScrollController();
  late final _reselect = context.read<TabReselect>();
  late final _viewModel = ClaimsViewModel(context.read(), context.read());

  @override
  void initState() {
    super.initState();
    _reselect.addListener(_onReselect);
  }

  void _onReselect() {
    if (_reselect.index == 1 && _scroll.hasClients) {
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
  }

  @override
  void dispose() {
    _reselect.removeListener(_onReselect);
    _scroll.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _viewModel,
    builder: (context, _) {
      final claims = _viewModel.visible;
      final settled = _viewModel.showSettled;
      return PdLargeTitleScaffold(
        title: 'Claims',
        heroTag: 'claims',
        controller: _scroll,
        trailing: ScanButton(
          key: const ValueKey('claims-scan'),
          onTap: () => AddFlow.start(context),
          onLongPress: () => AddFlow.camera(context),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: PdChipRow(
              children: [
                PdFilterChip(
                  key: const ValueKey('claim-open-filter'),
                  label: 'OPEN',
                  count: _viewModel.openCount,
                  selected: !settled,
                  onTap: () => _viewModel.filter(settled: false),
                ),
                PdFilterChip(
                  key: const ValueKey('claim-settled-filter'),
                  label: 'SETTLED',
                  count: _viewModel.settledCount,
                  selected: settled,
                  onTap: () => _viewModel.filter(settled: true),
                ),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(Pd.margin, Pd.s3, Pd.margin, 0),
            sliver: claims.isEmpty
                ? SliverToBoxAdapter(
                    child: DashedTile(
                      title: settled
                          ? 'No settled claims yet'
                          : 'No open claims',
                      body: settled ? 'Settled claims will appear here.' : 'Start a claim from a bill or policy in your vault.',
                      action: settled
                          ? null
                          : PdButton.primary(
                              key: const ValueKey('claims-open-vault'),
                              label: 'Open vault',
                              onPressed: () => context.go(Routes.vault),
                            ),
                    ),
                  )
                : SliverList.builder(
                    itemCount: claims.length,
                    itemBuilder: (context, index) {
                      final claim = claims[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: Pd.s3),
                        child: _ClaimRow(
                          key: ValueKey('claim-row-${claim.id}'),
                          claim: claim,
                          today: _viewModel.today,
                          onTap: () => context.push(Routes.claim(claim.id)),
                        ),
                      );
                    },
                  ),
          ),
        ],
      );
    },
  );
}

class _ClaimRow extends StatelessWidget {
  const _ClaimRow({
    required this.claim,
    required this.today,
    required this.onTap,
    super.key,
  });

  final Claim claim;
  final DateTime today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = claim.status(today).stamp;
    final day = claim.day(today);
    const radius = BorderRadius.all(Radius.circular(Pd.rSm));
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: '${claim.title}, ${status.word.toLowerCase()}, day $day',
      onTap: onTap,
      child: Material(
        color: Pd.surface2,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.all(Pd.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(claim.title, style: PdType.cardTitle),
                const SizedBox(height: Pd.s1),
                Text(
                  claim.itemLabel,
                  style: PdType.callout.copyWith(color: Pd.textMuted),
                ),
                const SizedBox(height: Pd.s3),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: Pd.s3,
                  runSpacing: Pd.s2,
                  children: [
                    PdStamp(status, angleDegrees: 0),
                    Text(
                      'DAY $day',
                      style: PdType.dataStrong.copyWith(
                        color: claim.isOpen ? Pd.signal : Pd.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
