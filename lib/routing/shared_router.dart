import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../ui/core/theme/tokens.dart';
import '../ui/core/widgets/tab_bar.dart';
import '../ui/features/account/account_screen.dart';
import '../ui/features/account/shared_session.dart';
import '../ui/features/account/shared_vault_screens.dart';
import '../ui/features/intro/intro_flow.dart';
import '../ui/features/settings/shared_settings_screen.dart';
import '../ui/features/vault/shared_vault_screen.dart';

GoRouter buildSharedRouter(SharedSession session) => GoRouter(
  initialLocation: '/vault',
  refreshListenable: session,
  redirect: (context, state) {
    final signingIn = const {
      '/intro',
      '/account',
    }.contains(state.matchedLocation);
    // Signed out, the app opens on the intro, which leads to the account.
    if (!session.signedIn && !signingIn) return '/intro';
    if (session.signedIn && signingIn) return '/vault';
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
        builder: (context, child) => Scaffold(
          backgroundColor: Pd.bg,
          body: child,
          bottomNavigationBar: PdTabBar(
            currentIndex: shell.currentIndex,
            claimsBadge:
                session.vault?.claims
                    .where((claim) => claim.needsAction)
                    .length ??
                0,
            onTap: (index) => shell.goBranch(
              index,
              initialLocation: index == shell.currentIndex,
            ),
          ),
        ),
        child: shell,
      ),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/vault',
              builder: (context, state) => const SharedVaultScreen(),
              routes: [
                GoRoute(
                  path: 'item/:id',
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
              path: '/claims',
              builder: (context, state) => const SharedClaimsScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (context, state) =>
                      SharedClaimScreen(state.pathParameters['id']!),
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
            ),
          ],
        ),
      ],
    ),
  ],
);
