import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../ui/core/theme/tokens.dart';
import '../ui/core/widgets/tab_bar.dart';
import '../ui/features/account/account_screen.dart';
import '../ui/features/account/shared_session.dart';
import '../ui/features/account/shared_vault_screens.dart';

GoRouter buildSharedRouter(SharedSession session) => GoRouter(
  initialLocation: '/vault',
  refreshListenable: session,
  redirect: (context, state) {
    final signingIn = state.matchedLocation == '/account';
    if (!session.signedIn && !signingIn) return '/account';
    if (session.signedIn && signingIn) return '/vault';
    return null;
  },
  routes: [
    GoRoute(
      path: '/account',
      builder: (context, state) => AccountScreen(session: session),
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
