import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../routing/router.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/type.dart';
import '../../core/widgets/brand_bar.dart';
import '../../core/widgets/button.dart';
import '../../core/widgets/list_row.dart';
import '../../core/widgets/nav.dart';
import '../../core/widgets/snackbar.dart';
import '../account/shared_session.dart';
import '../reminders/notification_preview.dart' show PaperGrain;
import 'shared_reminder_settings.dart';
import 'shared_settings_widgets.dart';

class SharedSettingsScreen extends StatefulWidget {
  const SharedSettingsScreen({this.notificationsOnly = false, super.key});

  final bool notificationsOnly;

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
    int? leadDays,
    bool? emailReminders,
  }) async {
    try {
      await session.updateReminders(
        leadDays: leadDays,
        emailReminders: emailReminders,
      );
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
    if (widget.notificationsOnly) {
      return PdPushedScaffold(
        backLabel: 'Settings',
        glassBack: true,
        onBack: () =>
            context.canPop() ? context.pop() : context.go(Routes.settings),
        title: 'Reminders & notifications',
        children: [
          SharedReminderSettings(
            profile: profile,
            email: session.email,
            loading: session.loading,
            onLeadChanged: canEditReminders
                ? (days) => _saveReminders(session, leadDays: days)
                : null,
            onEmailChanged: canEditReminders
                ? (enabled) => _saveReminders(session, emailReminders: enabled)
                : null,
            onOpenWeb: () => _openWeb(session, '/settings#reminders'),
          ),
        ],
      );
    }
    return Scaffold(
      backgroundColor: Pd.bg,
      body: CustomPaint(
        painter: const PaperGrain(),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Pd.maxContent),
            child: Column(
              children: [
                PdBrandBar(onMarkTap: () => context.go('/vault')),
                Expanded(
                  child: RefreshIndicator.adaptive(
                    onRefresh: session.refresh,
                    child: ListView(
                      key: const PageStorageKey('shared-settings-scroll'),
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        Pd.margin,
                        Pd.s2,
                        Pd.margin,
                        Pd.s8 + MediaQuery.paddingOf(context).bottom,
                      ),
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: Pd.s6,
                          children: [
                            Semantics(
                              header: true,
                              child: Text('Settings', style: PdType.heroTitle),
                            ),
                            SettingsSection(
                              title: 'Account',
                              description: 'Your Paper Drawer account.',
                              children: [
                                SharedSettingsAccount(
                                  name: session.displayName,
                                  email: session.email,
                                  signingOut: _signingOut,
                                  onSignOut: () => _signOut(session),
                                ),
                              ],
                            ),
                            SettingsSection(
                              title: 'Plan',
                              description:
                                  'What you get, and how much of it you use.',
                              children: [
                                SharedSettingsPlan(
                                  vault: session.vault,
                                  failed: session.failed,
                                  onRetry: session.refresh,
                                ),
                              ],
                            ),
                            PdListGroup(
                              children: [
                                PdListRow(
                                  key: const ValueKey(
                                    'settings-open-notifications',
                                  ),
                                  title: 'Reminders & notifications',
                                  chevron: true,
                                  onTap: () => context.push(
                                    Routes.settingsNotifications,
                                  ),
                                ),
                              ],
                            ),
                            SettingsSection(
                              title: 'Your data',
                              description:
                                  'Export your drawer or delete your account.',
                              children: [
                                SharedSettingsDataAction(
                                  title: 'Export your drawer',
                                  description: 'Get a spreadsheet of your items and claims, plus all original documents, in one ZIP on the web.',
                                  button: PdButton.secondary(
                                    key: const ValueKey(
                                      'shared-settings-export',
                                    ),
                                    label: 'Download export',
                                    onPressed: () =>
                                        _openWeb(session, '/settings#data'),
                                  ),
                                ),
                                SharedSettingsDataAction(
                                  title: 'Delete account',
                                  description: 'Permanently removes your documents, claims and reminders. You’ll confirm on the web.',
                                  button: PdButton.destructive(
                                    key: const ValueKey(
                                      'shared-settings-delete',
                                    ),
                                    label: 'Delete account',
                                    onPressed: () =>
                                        _openWeb(session, '/delete-account'),
                                  ),
                                  separated: true,
                                ),
                              ],
                            ),
                            PdListGroup(
                              children: [
                                PdListRow(
                                  key: const ValueKey('settings-legal'),
                                  title: 'Legal & about',
                                  chevron: true,
                                  onTap: () => context.push(Routes.legal),
                                ),
                                FutureBuilder(
                                  future: _version,
                                  builder: (context, state) => PdListRow(
                                    title: 'Version',
                                    value: state.data ?? '—',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
