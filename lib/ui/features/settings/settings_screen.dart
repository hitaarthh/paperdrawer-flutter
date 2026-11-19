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
import '../../core/widgets/brand_bar.dart';
import '../../core/widgets/list_row.dart';
import '../../core/widgets/nav.dart';
import '../../core/widgets/sheets.dart';
import '../../core/widgets/snackbar.dart';
import '../shell/tab_reselect.dart';
import 'settings_view_model.dart';
import 'shared_settings_widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({this.notificationsOnly = false, super.key});

  final bool notificationsOnly;

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
    child: _SettingsView(notificationsOnly: notificationsOnly),
  );
}

class _SettingsView extends StatefulWidget {
  const _SettingsView({required this.notificationsOnly});

  final bool notificationsOnly;

  @override
  State<_SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<_SettingsView> {
  final _scroll = ScrollController();
  late final _reselect = widget.notificationsOnly
      ? null
      : context.read<TabReselect>();

  @override
  void initState() {
    super.initState();
    _reselect?.addListener(_onReselect);
  }

  void _onReselect() {
    if (_reselect?.index != 2 || !_scroll.hasClients) return;
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
    _reselect?.removeListener(_onReselect);
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
      message: 'This permanently removes your Paper Drawer data and originals from this device.',
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
    if (widget.notificationsOnly) {
      return PdPushedScaffold(
        backLabel: 'Settings',
        glassBack: true,
        onBack: () =>
            context.canPop() ? context.pop() : context.go(Routes.settings),
        title: 'Reminders & notifications',
        children: [
          Text(
            'Choose when Paper Drawer sends reminders to this iPhone. Times set on individual files take priority.',
            style: PdType.detail.copyWith(color: Pd.textMuted),
          ),
          const SizedBox(height: Pd.s4),
          PdListGroup(
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
                        : (value) => _perform(model, model.setReminders(value)),
                  ),
                ),
              ),
              PdListRow(
                key: const ValueKey('settings-reminder-lead'),
                title: 'Automatic reminders',
                value: daysWord(model.leadDays),
                onTap: model.busy ? null : () => _chooseLead(model),
                chevron: true,
              ),
            ],
          ),
        ],
      );
    }
    return Scaffold(
      backgroundColor: Pd.bg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Pd.maxContent),
          child: Column(
            children: [
              PdBrandBar(onMarkTap: () => context.go(Routes.vault)),
              Expanded(
                child: ListView(
                  controller: _scroll,
                  padding: EdgeInsets.fromLTRB(
                    Pd.margin,
                    Pd.s3,
                    Pd.margin,
                    Pd.s8 + MediaQuery.paddingOf(context).bottom,
                  ),
                  children: [
                    Semantics(
                      header: true,
                      child: Text('Settings', style: PdType.heroTitle),
                    ),
                    const SizedBox(height: Pd.s6),
                    const SettingsSection(
                      title: 'Account',
                      description: 'Your drawer is stored on this iPhone.',
                      children: [
                        PdListGroup(
                          children: [PdListRow(title: 'On this iPhone')],
                        ),
                      ],
                    ),
                    const SizedBox(height: Pd.s6),
                    SettingsSection(
                      title: 'Plan',
                      children: [
                        PdListGroup(
                          children: [
                            PdListRow(
                              title: 'Base · Free',
                              value: '${model.active} of $baseItemLimit items',
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: Pd.s6),
                    PdListGroup(
                      children: [
                        PdListRow(
                          key: const ValueKey('settings-open-notifications'),
                          title: 'Reminders & notifications',
                          value: model.remindersOn ? 'On' : 'Off',
                          chevron: true,
                          onTap: () =>
                              context.push(Routes.settingsNotifications),
                        ),
                      ],
                    ),
                    const SizedBox(height: Pd.s6),
                    SettingsSection(
                      title: 'Your data',
                      description:
                          'Manage and export the files stored on this iPhone.',
                      children: [
                        PdListGroup(
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
                                    : () => _perform(
                                        model,
                                        model.export(_origin(anchor)),
                                      ),
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
                      ],
                    ),
                    const SizedBox(height: Pd.s6),
                    PdListGroup(
                      children: [
                        PdListRow(
                          key: const ValueKey('settings-legal'),
                          title: 'Legal & about',
                          chevron: true,
                          onTap: () => context.push(Routes.legal),
                        ),
                        FutureBuilder(
                          future: model.version,
                          builder: (context, state) => PdListRow(
                            title: 'Version',
                            value: state.data ?? '—',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
