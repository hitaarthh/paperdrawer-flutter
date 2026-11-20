import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/claim_repository.dart';
import '../../../data/repositories/item_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../data/services/drawer_actions.dart';
import '../../../data/services/exporter.dart';
import '../../../data/services/reminder_scheduler.dart';
import '../../../domain/formats.dart';
import '../../../routing/router.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/type.dart';
import '../../core/widgets/button.dart';
import '../../core/widgets/list_row.dart';
import '../../core/widgets/sheets.dart';
import '../../core/widgets/snackbar.dart';
import '../account/drawer_account_actions.dart';
import '../shell/tab_reselect.dart';
import 'settings_view_model.dart';
import 'shared_settings_widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({this.destination, super.key});

  final SettingsDestination? destination;

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
    child: _SettingsView(destination: destination),
  );
}

class _SettingsView extends StatefulWidget {
  const _SettingsView({required this.destination});

  final SettingsDestination? destination;

  @override
  State<_SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<_SettingsView> {
  final _scroll = ScrollController();
  bool _signingOut = false;
  late final _reselect = widget.destination == null
      ? context.read<TabReselect>()
      : null;

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
        for (final days in model.selectableLeadDays)
          PdAction(label: daysWord(days), value: days),
      ],
    );
    if (!mounted || lead == null) return;
    await _perform(model, model.setLeadDays(lead));
  }

  Future<void> _signOut(DrawerAccountActions account) async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    try {
      await account.signOut();
    } catch (_) {
      if (!mounted) return;
      setState(() => _signingOut = false);
      showPdSnackbar(context, 'Couldn’t sign out. Try again.');
    }
  }

  Future<void> _importLegacy(VoidCallback import) async {
    final confirm = await showPdConfirm(
      context,
      title: 'Import the previous drawer?',
      message: 'Import these files only if they belong to you. Paper Drawer will link the previous drawer to this account.',
      confirmLabel: 'Import drawer',
    );
    if (!mounted || !confirm) return;
    import();
  }

  Future<void> _erase(SettingsViewModel model) async {
    final confirm = await showPdConfirm(
      context,
      title: 'Clear this drawer?',
      message:
          'This permanently removes the records and originals in this drawer.',
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
    final account = context.watch<DrawerAccountActions?>();
    final name = model.profileName?.trim();
    return switch (widget.destination) {
      SettingsDestination.account when account == null => const SettingsSubpage(
        title: 'Account',
        children: [
          PdListGroup(
            children: [
              PdListRow(
                title: 'On this iPhone',
                leadingIcon: LucideIcons.smartphone,
              ),
            ],
          ),
          SizedBox(height: Pd.s4),
          SharedSettingsDetail(
            'Your originals and reminders are stored on this iPhone.',
          ),
        ],
      ),
      SettingsDestination.account => SettingsSubpage(
        title: 'Account',
        children: [
          PdListGroup(
            children: [
              PdListRow(
                title: name == null || name.isEmpty ? account!.name : name,
                leadingIcon: LucideIcons.user,
              ),
              if (account!.email case final email?)
                PdListRow(title: email, leadingIcon: LucideIcons.mail),
            ],
          ),
          const SizedBox(height: Pd.s4),
          const SharedSettingsDetail(
            'Signing out locks your drawer. Sign back in to open it on this iPhone.',
          ),
          const SizedBox(height: Pd.s5),
          PdButton.secondary(
            key: const ValueKey('account-sign-out'),
            label: 'Sign out',
            busy: _signingOut,
            onPressed: () => _signOut(account),
          ),
        ],
      ),
      SettingsDestination.plan => SettingsSubpage(
        title: 'Plan',
        children: [
          SettingsPlanCard(used: model.active, onBase: model.onBasePlan),
        ],
      ),
      SettingsDestination.notifications => SettingsSubpage(
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
          if (account != null) ...[
            const SizedBox(height: Pd.s4),
            PdListGroup(
              children: [
                PdListRow(
                  title: 'Account email reminders',
                  trailing: PdSwitch(
                    key: const ValueKey('settings-email-reminders'),
                    value: model.emailReminders,
                    onChanged: model.busy
                        ? null
                        : (value) =>
                              _perform(model, model.setEmailReminders(value)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Pd.s2),
            const SharedSettingsDetail(
              'Email reminders apply to files stored online.',
            ),
          ],
        ],
      ),
      SettingsDestination.data => SettingsSubpage(
        title: 'Your data',
        children: [
          const SharedSettingsDetail(
            'Manage and back up the files stored on this iPhone.',
          ),
          const SizedBox(height: Pd.s4),
          SettingsMenu(
            children: [
              PdListRow(
                key: const ValueKey('settings-archive'),
                title: 'Archive',
                value: model.archived.toString(),
                leadingIcon: LucideIcons.archive,
                chevron: true,
                onTap: () => context.push(Routes.archive),
              ),
              Builder(
                builder: (anchor) => PdListRow(
                  key: const ValueKey('settings-export'),
                  title: 'Export everything',
                  leadingIcon: LucideIcons.download,
                  chevron: true,
                  onTap: model.busy
                      ? null
                      : () => _perform(model, model.export(_origin(anchor))),
                ),
              ),
              PdListRow(
                key: const ValueKey('settings-clear'),
                title: 'Clear this drawer',
                leadingIcon: LucideIcons.trash2,
                destructive: true,
                onTap: model.busy ? null : () => _erase(model),
              ),
              if (account?.importLegacy case final import?)
                PdListRow(
                  key: const ValueKey('settings-import-legacy'),
                  title: 'Import previous drawer',
                  leadingIcon: LucideIcons.folderInput,
                  chevron: true,
                  onTap: model.busy ? null : () => _importLegacy(import),
                ),
            ],
          ),
        ],
      ),
      null => SettingsOverview(
        controller: _scroll,
        account: SettingsAccountCard(
          name: name == null || name.isEmpty
              ? account?.name ?? 'On this iPhone'
              : name,
          description: account?.email ?? 'Files stored on this device',
        ),
        plan: model.onBasePlan ? 'Base · Free' : 'Pro',
        notifications: model.remindersOn ? 'On' : 'Off',
        version: model.version,
      ),
    };
  }
}
