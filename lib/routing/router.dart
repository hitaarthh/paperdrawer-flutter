import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:go_router/go_router.dart';

import '../domain/models/item.dart';
import '../ui/features/add/add_details_args.dart';
import '../ui/features/add/camera_screen.dart';
import '../ui/features/add/item_form_screen.dart';
import '../ui/features/add/reading_screen.dart';
import '../ui/features/claims/claim_detail_screen.dart';
import '../ui/features/claims/claims_screen.dart';
import '../ui/features/claims/start_claim_screen.dart';
import '../ui/features/item/item_detail_screen.dart';
import '../ui/features/reminders/reminders_screen.dart';
import '../ui/features/settings/archive_screen.dart';
import '../ui/features/settings/settings_screen.dart';
import '../ui/features/shell/app_shell.dart';
import '../ui/features/vault/vault_screen.dart';

/// Locations used across the app and in reminder payloads.
abstract final class Routes {
  static const vault = '/vault';
  static const claims = '/claims';
  static const settings = '/settings';
  static const archive = '/settings/archive';
  static const camera = '/add/camera';
  static const reading = '/add/reading';
  static const details = '/add/details';
  static const reminders = '/reminders';

  static String item(String id) => '/vault/item/$id';
  static String startClaim(String itemId) => '/vault/item/$itemId/claim';
  static String claim(String id) => '/claims/$id';
  static String edit(String id) => '/edit/$id';
}

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

GoRouter buildRouter({String? initialLocation}) => GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: initialLocation ?? Routes.vault,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => AppShell(navigationShell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.vault,
              builder: (context, state) => VaultScreen(
                reviewOld: state.uri.queryParameters['review'] == 'old',
              ),
              routes: [
                GoRoute(
                  path: 'item/:id',
                  builder: (context, state) =>
                      ItemDetailScreen(id: state.pathParameters['id']!),
                  routes: [
                    GoRoute(
                      path: 'claim',
                      builder: (context, state) =>
                          StartClaimScreen(itemId: state.pathParameters['id']!),
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
              path: Routes.claims,
              builder: (context, state) => const ClaimsScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (context, state) =>
                      ClaimDetailScreen(id: state.pathParameters['id']!),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.settings,
              builder: (context, state) => const SettingsScreen(),
              routes: [
                GoRoute(
                  path: 'archive',
                  builder: (context, state) => const ArchiveScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    // Flows cover the tab bar and slide up like a modal.
    GoRoute(
      path: Routes.camera,
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) => CupertinoPage(
        key: state.pageKey,
        fullscreenDialog: true,
        child: CameraScreen(
          kind: state.extra is ItemKind ? state.extra! as ItemKind : null,
        ),
      ),
    ),
    GoRoute(
      path: Routes.reading,
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) => CupertinoPage(
        key: state.pageKey,
        fullscreenDialog: true,
        child: switch (state.extra) {
          final CaptureReadingArgs args => ReadingScreen(
            files: args.files,
            kind: args.kind,
          ),
          final List<PendingFile> files => ReadingScreen(files: files),
          _ => const ReadingScreen(files: []),
        },
      ),
    ),
    GoRoute(
      path: Routes.details,
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) => CupertinoPage(
        key: state.pageKey,
        fullscreenDialog: true,
        child: ItemFormScreen.create(
          state.extra is AddDetailsArgs
              ? state.extra! as AddDetailsArgs
              : const AddDetailsArgs(),
        ),
      ),
    ),
    // The one-time "Turn on reminders" offer, pushed after a first save.
    GoRoute(
      path: Routes.reminders,
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) => CupertinoPage(
        key: state.pageKey,
        fullscreenDialog: true,
        child: const RemindersScreen(),
      ),
    ),
    GoRoute(
      path: '/edit/:id',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) => CupertinoPage(
        key: state.pageKey,
        fullscreenDialog: true,
        child: ItemFormScreen.edit(state.pathParameters['id']!),
      ),
    ),
  ],
);
