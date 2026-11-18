import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/type.dart';
import '../../core/widgets/brand_bar.dart';
import '../../core/widgets/button.dart';
import '../../core/widgets/snackbar.dart';
import '../account/shared_session.dart';
import '../reminders/notification_preview.dart' show PaperGrain;
import 'shared_reminder_settings.dart';
import 'shared_settings_widgets.dart';

class SharedSettingsScreen extends StatefulWidget {
  const SharedSettingsScreen({super.key});

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
                      padding: const EdgeInsets.fromLTRB(
                        Pd.margin,
                        Pd.s2,
                        Pd.margin,
                        Pd.s8,
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
                            SharedSettingsSection(
                              title: 'Account',
                              description: 'The account your vault belongs to.',
                              children: [
                                SharedSettingsAccount(
                                  name: session.displayName,
                                  email: session.email,
                                  signingOut: _signingOut,
                                  onSignOut: () => _signOut(session),
                                ),
                              ],
                            ),
                            SharedSettingsSection(
                              title: 'Plan',
                              description:
                                  'What you get, and how much of it you use.',
                              children: [
                                SharedSettingsPlan(
                                  vault: session.vault,
                                  failed: session.failed,
                                  onRetry: session.refresh,
                                  onSeePlans: () =>
                                      _openWeb(session, '/pricing'),
                                ),
                              ],
                            ),
                            SharedSettingsSection(
                              title: 'Reminders',
                              description: 'How early we tell you before returns close, warranties end and policies renew.',
                              children: [
                                SharedReminderSettings(
                                  profile: profile,
                                  email: session.email,
                                  loading: session.loading,
                                  onLeadChanged: canEditReminders
                                      ? (days) => _saveReminders(
                                          session,
                                          leadDays: days,
                                        )
                                      : null,
                                  onEmailChanged: canEditReminders
                                      ? (enabled) => _saveReminders(
                                          session,
                                          emailReminders: enabled,
                                        )
                                      : null,
                                  onOpenWeb: () =>
                                      _openWeb(session, '/settings#reminders'),
                                ),
                              ],
                            ),
                            SharedSettingsSection(
                              title: 'Email import',
                              description: 'Forward order and policy emails and they land here, already read.',
                              children: [
                                Row(
                                  spacing: Pd.s3,
                                  children: [
                                    const Expanded(
                                      child: SharedSettingsDetail(
                                        'Your own forwarding address comes with Pro.',
                                      ),
                                    ),
                                    Text(
                                      'PRO · SOON',
                                      style: PdType.tabLabel.copyWith(
                                        color: Pd.signal,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            SharedSettingsSection(
                              title: 'Your data',
                              description:
                                  'Export your vault or delete your account.',
                              children: [
                                SharedSettingsDataAction(
                                  title: 'Export your vault',
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
                            SharedSettingsFooter(
                              version: _version,
                              onPrivacy: () => _openWeb(session, '/privacy'),
                              onTerms: () => _openWeb(session, '/terms'),
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
