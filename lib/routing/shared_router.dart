import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../ui/core/theme/tokens.dart';
import '../ui/core/widgets/tab_bar.dart';
import '../ui/features/account/account_screen.dart';
import '../ui/features/account/shared_session.dart';
import '../ui/features/account/shared_vault_screens.dart';
import '../ui/features/add/shared_add_flow.dart';
import '../ui/features/claims/shared_claim_ledger_screen.dart';
import '../ui/features/home/coming_up_screen.dart';
import '../ui/features/intro/intro_flow.dart';
import '../ui/features/reminders/reminder_inbox.dart';
import '../ui/features/settings/legal_settings_screen.dart';
import '../ui/features/settings/shared_settings_screen.dart';
import '../ui/features/vault/shared_vault_screen.dart';
import 'router.dart';

GoRouter buildSharedRouter(SharedSession session) {
  final navigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shared root');
  return GoRouter(
  navigatorKey: navigatorKey,
  initialLocation: '/home',
  refreshListenable: session,
  redirect: (context, state) {
    final signingIn = const {
      '/intro',
      '/account',
    }.contains(state.matchedLocation);
    // Signed out, the app opens on the intro, which leads to the account.
    if (!session.signedIn && !signingIn) return '/intro';
    if (session.signedIn && signingIn) return '/home';
    return null;
  },
  routes: [
    GoRoute(
      path: '/intro',
      builder: (context, state) => IntroFlow(
        onStart: () => context.go('/account?mode=create'),
        onSignIn: () => context.go('/account'),
      ),
    ),
    GoRoute(
      path: '/account',
      builder: (context, state) => AccountScreen(
        // A new key per mode, so switching modes from the intro resets it.
        key: ValueKey(state.uri.queryParameters['mode']),
        session: session,
        startCreating: state.uri.queryParameters['mode'] == 'create',
      ),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => ListenableBuilder(
        listenable: session,
        builder: (context, child) {
          final vault = session.vault;
          return Scaffold(
            backgroundColor: Pd.bg,
            extendBody: true,
            body: child,
            bottomNavigationBar: PdTabBar(
              currentIndex: shell.currentIndex,
              homeFirst: true,
              onTap: (index) => shell.goBranch(
                index,
                initialLocation: index == shell.currentIndex,
              ),
              onScan: vault == null
                  ? null
                  : () => showSharedManualAdd(context, vault),
            ),
          );
        },
        child: shell,
      ),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const ComingUpScreen(shared: true),
              routes: [
                GoRoute(
                  path: 'item/:id',
                  parentNavigatorKey: navigatorKey,
                  builder: (context, state) => SharedItemScreen(
                    state.pathParameters['id']!,
                    fromHome: true,
                  ),
                ),
              ],
            ),
            GoRoute(
              path: '/claims',
              builder: (context, state) =>
                  const ClaimHistoryScreen(shared: true),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (context, state) =>
                      SharedClaimLedgerScreen(state.pathParameters['id']!),
                  routes: [
                    GoRoute(
                      path: 'guidance',
                      builder: (context, state) =>
                          SharedClaimScreen(state.pathParameters['id']!),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/vault',
              builder: (context, state) => SharedVaultScreen(
                showDue: state.uri.queryParameters['filter'] == 'due',
              ),
              routes: [
                GoRoute(
                  path: 'item/:id',
                  parentNavigatorKey: navigatorKey,
                  builder: (context, state) =>
                      SharedItemScreen(state.pathParameters['id']!),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SharedSettingsScreen(),
              routes: [
                GoRoute(
                  path: 'notifications',
                  parentNavigatorKey: navigatorKey,
                  builder: (context, state) => const SharedSettingsScreen(notificationsOnly: true),
                ),
                ...legalRoutes(navigatorKey),
              ],
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: Routes.notifications,
      parentNavigatorKey: navigatorKey,
      builder: (context, state) => ReminderInbox(
        fromDrawer: state.extra == true,
        shared: true,
      ),
    ),
    ...buildAddRoutes(navigatorKey: navigatorKey, shared: true),
  ],
);
}
