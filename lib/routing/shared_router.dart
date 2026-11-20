import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../ui/core/widgets/glass.dart';
import '../ui/core/theme/tokens.dart';
import '../ui/core/widgets/tab_bar.dart';
import '../ui/features/account/account_screen.dart';
import '../ui/features/account/shared_session.dart';
import '../ui/features/account/shared_vault_screens.dart';
import '../ui/features/add/shared_add_flow.dart';
import '../ui/features/home/coming_up_screen.dart';
import '../ui/features/intro/intro_flow.dart';
import '../ui/features/reminders/reminder_inbox.dart';
import '../ui/features/settings/legal_settings_screen.dart';
import '../ui/features/settings/shared_settings_widgets.dart';
import '../ui/features/settings/shared_settings_screen.dart';
import '../ui/features/vault/shared_vault_screen.dart';
import 'paper_page.dart';
import 'router.dart';

GoRouter buildSharedRouter(SharedSession session) {
  final navigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shared root');
  return GoRouter(
    navigatorKey: navigatorKey,
    observers: pdGlassNavigatorObservers(),
    initialLocation: '/home',
    // Vault updates can land during a pop. Only account changes affect redirects.
    refreshListenable: session.routingAccountChanges,
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
          account: session.account,
          openWeb: session.openWeb,
          startCreating: state.uri.queryParameters['mode'] == 'create',
        ),
      ),
      StatefulShellRoute.indexedStack(
        pageBuilder: (context, state, shell) => PdPage<void>(
          key: state.pageKey,
          child: Scaffold(
            backgroundColor: Pd.bg,
            extendBody: true,
            body: shell,
            bottomNavigationBar: PdTabBar(
              currentIndex: shell.currentIndex,
              onTap: (index) => shell.goBranch(
                index,
                initialLocation: index == shell.currentIndex,
              ),
              onScan: () => showSharedManualAdd(context, session.vault),
            ),
          ),
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
                    pageBuilder: (context, state) => PdPage<void>(
                      key: state.pageKey,
                      child: SharedItemScreen(
                        state.pathParameters['id']!,
                        fromHome: true,
                      ),
                    ),
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
                    pageBuilder: (context, state) => PdPage<void>(
                      key: state.pageKey,
                      child: SharedItemScreen(state.pathParameters['id']!),
                    ),
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
                  for (final destination in SettingsDestination.values)
                    GoRoute(
                      path: destination.name,
                      parentNavigatorKey: navigatorKey,
                      pageBuilder: (context, state) => PdPage<void>(
                        key: state.pageKey,
                        child: SharedSettingsScreen(destination: destination),
                      ),
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
        pageBuilder: (context, state) => PdPage<void>(
          key: state.pageKey,
          child: ReminderInbox(fromDrawer: state.extra == true, shared: true),
        ),
      ),
      ...retiredClaimLinks(),
      ...buildAddRoutes(navigatorKey: navigatorKey, shared: true),
      buildEditRoute(navigatorKey: navigatorKey, shared: true),
    ],
  );
}
