import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/claim_repository.dart';
import '../../../data/repositories/item_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../data/services/drawer_actions.dart';
import '../../../data/services/exporter.dart';
import '../../../data/services/reminder_scheduler.dart';
import '../../../domain/formats.dart';
import '../../../domain/item_status.dart';
import '../../../routing/router.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/type.dart';
import '../../core/widgets/list_row.dart';
import '../../core/widgets/nav.dart';
import '../../core/widgets/sheets.dart';
import '../../core/widgets/snackbar.dart';
import '../shell/tab_reselect.dart';
import 'settings_view_model.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (context) => SettingsViewModel(
      context.read<SettingsRepository>(),
      context.read<ItemRepository>(),
      context.read<ClaimRepository>(),
      context.read<Exporter>(),
      context.read<DrawerActions>(),
      context.read<ReminderScheduler?>(),
    ),
    child: const _SettingsView(),
  );
}

class _SettingsView extends StatefulWidget {
  const _SettingsView();

  @override
  State<_SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<_SettingsView> {
  final _scroll = ScrollController();
  late final _reselect = context.read<TabReselect>();

  @override
  void initState() {
    super.initState();
    _reselect.addListener(_onReselect);
  }

  void _onReselect() {
    if (_reselect.index != 2 || !_scroll.hasClients) return;
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
    super.dispose();
  }

  Future<void> _perform(
    SettingsViewModel model,
    Future<bool> operation, {
    String? success,
  }) async {
    final didWrite = await operation;
    if (!mounted) return;
    if (didWrite && success != null) {
      showPdSnackbar(context, success, success: true);
    } else if (!didWrite && model.error != null) {
      showPdSnackbar(context, model.error!);
    }
  }

  Future<void> _chooseLead(SettingsViewModel model) async {
    final lead = await showPdActions<int>(
      context,
      title: 'Remind me before',
      actions: [
        for (final days in SettingsRepository.leadDayChoices)
          PdAction(label: daysWord(days), value: days),
      ],
    );
    if (!mounted || lead == null) return;
    await _perform(model, model.setLeadDays(lead));
  }

  Future<void> _erase(SettingsViewModel model) async {
    final confirm = await showPdConfirm(
      context,
      title: 'Clear this drawer?',
      message: 'This permanently removes all items, originals, claims and preferences from this device.',
      confirmLabel: 'Clear drawer',
      destructive: true,
    );
    if (!mounted || !confirm) return;
    await _perform(model, model.erase(), success: 'Drawer cleared');
  }

  Rect? _origin(BuildContext anchor) {
    final box = anchor.findRenderObject();
    return box is RenderBox && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<SettingsViewModel>();
    return PdLargeTitleScaffold(
      title: 'Settings',
      heroTag: 'settings',
      controller: _scroll,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: Pd.margin),
          sliver: SliverList.list(
            children: [
              PdListGroup(
                header: 'Reminders',
                children: [
                  PdListRow(
                    title: 'Device notifications',
                    trailing: Semantics(
                      label: 'Device notifications',
                      child: PdSwitch(
                        key: const ValueKey('settings-reminders'),
                        value: model.remindersOn,
                        onChanged: model.busy || !model.canRemind
                            ? null
                            : (value) =>
                                  _perform(model, model.setReminders(value)),
                      ),
                    ),
                  ),
                  PdListRow(
                    key: const ValueKey('settings-reminder-lead'),
                    title: 'Remind me before',
                    value: daysWord(model.leadDays),
                    onTap: model.busy ? null : () => _chooseLead(model),
                    chevron: true,
                  ),
                ],
              ),
              const SizedBox(height: Pd.s6),
              PdListGroup(
                header: 'Plan',
                children: [
                  PdListRow(
                    title: 'Base',
                    value: '${model.active} of $baseItemLimit items',
                  ),
                  PdListRow(
                    title: 'Pro waitlist',
                    value: 'Coming soon',
                    onTap: () => showPdSheet<void>(
                      context,
                      title: 'PaperDrawer Pro',
                      subtitle: 'The Pro waitlist is opening soon.',
                    ),
                    chevron: true,
                  ),
                ],
              ),
              const SizedBox(height: Pd.s6),
              PdListGroup(
                header: 'Your data',
                children: [
                  PdListRow(
                    key: const ValueKey('settings-archive'),
                    title: 'Archive',
                    value: model.archived.toString(),
                    chevron: true,
                    onTap: () => context.push(Routes.archive),
                  ),
                  Builder(
                    builder: (anchor) => PdListRow(
                      key: const ValueKey('settings-export'),
                      title: 'Export everything',
                      chevron: true,
                      onTap: model.busy
                          ? null
                          : () =>
                                _perform(model, model.export(_origin(anchor))),
                    ),
                  ),
                  PdListRow(
                    key: const ValueKey('settings-clear'),
                    title: 'Clear this drawer',
                    destructive: true,
                    onTap: model.busy ? null : () => _erase(model),
                  ),
                ],
              ),
              const SizedBox(height: Pd.s6),
              PdListGroup(
                header: 'About',
                children: [
                  PdListRow(
                    title: 'Privacy',
                    chevron: true,
                    onTap: () => showPdSheet<void>(
                      context,
                      title: 'Privacy',
                      subtitle: 'Your documents and claims stay on this device. Share or export them from your drawer whenever you choose.',
                    ),
                  ),
                  FutureBuilder(
                    future: model.version,
                    builder: (context, state) =>
                        PdListRow(title: 'Version', value: state.data ?? '—'),
                  ),
                ],
              ),
              const SizedBox(height: Pd.s5),
              Text(
                'PaperDrawer gives general guidance. For legal advice, speak to a qualified professional.',
                style: PdType.footnote.copyWith(color: Pd.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
