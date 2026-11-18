import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../routing/router.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/brand_bar.dart';
import '../../core/widgets/button.dart';
import '../../core/widgets/empty_state.dart';
import '../add/add_flow.dart';
import '../shell/tab_reselect.dart';
import 'claims_list_data.dart';
import 'claims_overview.dart';
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
    if (_reselect.index != 1 || !_scroll.hasClients) return;
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
    _reselect.removeListener(_onReselect);
    _scroll.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _viewModel,
    builder: (context, _) => ClaimsOverview(
      data: _viewModel.list,
      controller: _scroll,
      onVault: () => context.go(Routes.vault),
      onOpen: (id) => context.push(Routes.claim(id)),
      trailing: GestureDetector(
        onLongPress: () => AddFlow.camera(context),
        child: PdBrandAction(
          key: const ValueKey('claims-scan'),
          label: 'Scan or add',
          icon: LucideIcons.scanLine,
          onPressed: () => AddFlow.start(context),
        ),
      ),
      empty: (filter) => filter == ClaimsFilter.settled
          ? const DashedTile(
              title: 'No settled claims yet',
              body: 'Claims you mark as settled will appear here.',
            )
          : DashedTile(
              title: filter == ClaimsFilter.open
                  ? 'No open claims'
                  : 'No claims yet',
              body: 'Start a claim from a bill or policy in your vault.',
              action: PdButton.primary(
                key: const ValueKey('claims-open-vault'),
                label: 'Open vault',
                onPressed: () => context.go(Routes.vault),
              ),
            ),
    ),
  );
}
