import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/button.dart';
import '../../core/widgets/list_row.dart';
import '../../core/widgets/snackbar.dart';
import '../account/shared_session.dart';
import 'shared_reminder_settings.dart';
import 'shared_settings_widgets.dart';

class SharedSettingsScreen extends StatefulWidget {
  const SharedSettingsScreen({this.destination, super.key});

  final SettingsDestination? destination;

  @override
  State<SharedSettingsScreen> createState() => _SharedSettingsScreenState();
}

class _SharedSettingsScreenState extends State<SharedSettingsScreen> {
  late final _version = context.read<SharedSession>().appVersion();
  bool _signingOut = false;

  Future<void> _signOut(SharedSession session) async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    try {
      await session.account.signOut();
    } catch (_) {
      if (!mounted) return;
      showPdSnackbar(context, 'Couldn’t sign out. Try again.');
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  Future<void> _saveReminders(
    SharedSession session, {
    required int leadDays,
  }) async {
    try {
      await session.updateReminders(leadDays: leadDays);
    } catch (_) {
      if (!mounted) return;
      showPdSnackbar(context, 'Couldn’t save reminder settings. Try again.');
    }
  }

  Future<void> _openWeb(SharedSession session, String path) async {
    try {
      await session.openWeb(path);
    } catch (_) {
      if (!mounted) return;
      showPdSnackbar(context, 'Couldn’t open Paper Drawer on the web.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SharedSession>();
    final profile = session.vault?.profile;
    final canEditReminders =
        !_signingOut && !session.loading && !session.savingReminders;
    final vault = session.vault;
    final name = session.displayName;
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .take(2)
        .map((word) => word.characters.first.toUpperCase())
        .join();
    return switch (widget.destination) {
      SettingsDestination.account => SettingsSubpage(
        title: 'Account',
        children: [
          PdListGroup(
            children: [
              PdListRow(
                title: 'Name',
                value: name,
                leadingIcon: LucideIcons.user,
              ),
              if (session.email case final email?)
                PdListRow(
                  title: 'Email',
                  value: email,
                  leadingIcon: LucideIcons.mail,
                ),
            ],
          ),
          const SizedBox(height: Pd.s5),
          PdButton.secondary(
            key: const ValueKey('account-sign-out'),
            label: 'Sign out',
            busy: _signingOut,
            onPressed: () => _signOut(session),
          ),
        ],
      ),
      SettingsDestination.plan => SettingsSubpage(
        title: 'Plan',
        children: [
          SettingsPlanCard(
            used: vault?.items.length,
            onBase: vault?.onBasePlan ?? true,
            failed: session.failed,
            onRetry: session.refresh,
          ),
        ],
      ),
      SettingsDestination.notifications => SettingsSubpage(
        title: 'Reminders & notifications',
        children: [
          SharedReminderSettings(
            profile: profile,
            loading: session.loading,
            onLeadChanged: canEditReminders
                ? (days) => _saveReminders(session, leadDays: days)
                : null,
          ),
        ],
      ),
      SettingsDestination.data => SettingsSubpage(
        title: 'Your data',
        children: [
          const SharedSettingsDetail(
            'Download a backup of your originals and saved data on the web.',
          ),
          const SizedBox(height: Pd.s4),
          SettingsMenu(
            children: [
              PdListRow(
                key: const ValueKey('shared-settings-export'),
                title: 'Download export',
                leadingIcon: LucideIcons.download,
                chevron: true,
                onTap: () => _openWeb(session, '/settings#data'),
              ),
              PdListRow(
                key: const ValueKey('shared-settings-delete'),
                title: 'Delete account',
                leadingIcon: LucideIcons.trash2,
                destructive: true,
                chevron: true,
                onTap: () => _openWeb(session, '/delete-account'),
              ),
            ],
          ),
        ],
      ),
      null => SettingsOverview(
        account: SettingsAccountCard(
          name: name,
          description: session.email,
          initials: initials,
        ),
        plan: vault == null ? null : (vault.onBasePlan ? 'Base · Free' : 'Pro'),
        notifications: profile == null ? null : 'In-app',
        version: _version,
        onRefresh: session.refresh,
      ),
    };
  }
}
