import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:go_router/go_router.dart';

import '../domain/models/item.dart';
import '../ui/core/widgets/glass.dart';
import '../ui/features/add/add_details_args.dart';
import '../ui/features/add/camera_screen.dart';
import '../ui/features/add/item_form_screen.dart';
import '../ui/features/add/manual_item_form.dart';
import '../ui/features/add/reading_screen.dart';
import '../ui/features/home/coming_up_screen.dart';
import '../ui/features/item/item_detail_screen.dart';
import '../ui/features/reminders/reminders_screen.dart';
import '../ui/features/reminders/reminder_inbox.dart';
import '../ui/features/settings/legal_settings_screen.dart';
import '../ui/features/settings/shared_settings_widgets.dart';
import '../ui/features/settings/archive_screen.dart';
import '../ui/features/settings/settings_screen.dart';
import '../ui/features/shell/app_shell.dart';
import '../ui/features/vault/vault_screen.dart';
import 'paper_page.dart';

/// Locations used across the app and in reminder payloads.
abstract final class Routes {
  static const home = '/home';
  static const vault = '/vault';
  static const claims = '/claims';
  static const settings = '/settings';
  static const settingsAccount = '/settings/account';
  static const settingsPlan = '/settings/plan';
  static const settingsData = '/settings/data';
  static const settingsNotifications = '/settings/notifications';
  static const legal = '/settings/legal';
  static const licenses = '/settings/legal/licenses';
  static const archive = '/settings/archive';
  static const add = '/add';
  static const camera = '/add/camera';
  static const reading = '/add/reading';
  static const details = '/add/details';
  static const reminders = '/reminders';
  static const notifications = '/notifications';

  static String item(String id) => '/vault/item/$id';
  static String homeItem(String id) => '/home/item/$id';
  static String startClaim(String itemId) => '/vault/item/$itemId/claim';
  static String claim(String id) => '/claims/$id';
  static String claimGuidance(String id) => '/claims/$id/guidance';
  static String edit(String id) => '/edit/$id';
  static String vaultWithRecent(String id) =>
      Uri(path: vault, queryParameters: {'added': id}).toString();
}

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

GoRouter buildRouter({String? initialLocation}) => GoRouter(
  navigatorKey: rootNavigatorKey,
  observers: pdGlassNavigatorObservers(),
  initialLocation: initialLocation ?? Routes.home,
  routes: [
    StatefulShellRoute.indexedStack(
      pageBuilder: (context, state, shell) => PdPage<void>(
        key: state.pageKey,
        child: AppShell(navigationShell: shell),
      ),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.home,
              builder: (context, state) => const ComingUpScreen(),
              routes: [
                GoRoute(
                  path: 'item/:id',
                  parentNavigatorKey: rootNavigatorKey,
                  pageBuilder: (context, state) => PdPage<void>(
                    key: state.pageKey,
                    child: ItemDetailScreen(
                      id: state.pathParameters['id']!,
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
              path: Routes.vault,
              builder: (context, state) => VaultScreen(
                reviewOld: state.uri.queryParameters['review'] == 'old',
                showDue: state.uri.queryParameters['filter'] == 'due',
                addedId: state.uri.queryParameters['added'],
              ),
              routes: [
                GoRoute(
                  path: 'item/:id',
                  parentNavigatorKey: rootNavigatorKey,
                  pageBuilder: (context, state) => PdPage<void>(
                    key: state.pageKey,
                    child: ItemDetailScreen(id: state.pathParameters['id']!),
                  ),
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
                for (final destination in SettingsDestination.values)
                  GoRoute(
                    path: destination.name,
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (context, state) => PdPage<void>(
                      key: state.pageKey,
                      child: SettingsScreen(destination: destination),
                    ),
                  ),
                ...legalRoutes(rootNavigatorKey),
                GoRoute(
                  path: 'archive',
                  parentNavigatorKey: rootNavigatorKey,
                  pageBuilder: (context, state) => PdPage<void>(
                    key: state.pageKey,
                    child: const ArchiveScreen(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: Routes.notifications,
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) => PdPage<void>(
        key: state.pageKey,
        child: ReminderInbox(fromDrawer: state.extra == true),
      ),
    ),
    ...retiredClaimLinks(),
    ...buildAddRoutes(navigatorKey: rootNavigatorKey),
    // The one-time "Turn on reminders" offer, pushed after a first save.
    GoRoute(
      path: Routes.reminders,
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) => PdPage<void>(
        key: state.pageKey,
        fullscreenDialog: true,
        child: const RemindersScreen(),
      ),
    ),
    buildEditRoute(navigatorKey: rootNavigatorKey),
  ],
);

/// Old notification links and bookmarks lead to Home.
List<GoRoute> retiredClaimLinks() => [
  for (final path in [
    Routes.claims,
    '${Routes.claims}/:id',
    '${Routes.claims}/:id/guidance',
    '${Routes.vault}/item/:id/claim',
  ])
    GoRoute(path: path, redirect: (context, state) => Routes.home),
];

GoRoute buildEditRoute({
  required GlobalKey<NavigatorState> navigatorKey,
  bool shared = false,
}) => GoRoute(
  path: Routes.edit(':id'),
  parentNavigatorKey: navigatorKey,
  pageBuilder: (context, state) {
    final id = state.pathParameters['id']!;
    return PdPage<void>(
      key: state.pageKey,
      fullscreenDialog: true,
      child: ManualItemForm(key: ValueKey(id), id: id, shared: shared),
    );
  },
);

/// Capture and review cover the tab bar in both build modes.
List<GoRoute> buildAddRoutes({
  GlobalKey<NavigatorState>? navigatorKey,
  bool shared = false,
}) => [
  GoRoute(
    path: Routes.add,
    parentNavigatorKey: navigatorKey,
    pageBuilder: (context, state) => PdPage<void>(
      key: state.pageKey,
      fullscreenDialog: true,
      child: ManualItemForm(
        kind: state.extra is ItemKind
            ? state.extra! as ItemKind
            : ItemKind.bill,
        shared: shared,
      ),
    ),
  ),
  GoRoute(
    path: Routes.camera,
    parentNavigatorKey: navigatorKey,
    pageBuilder: (context, state) => PdPage<void>(
      key: state.pageKey,
      fullscreenDialog: true,
      child: CameraScreen(
        kind: state.extra is ItemKind ? state.extra! as ItemKind : null,
        singleOriginal: shared,
      ),
    ),
  ),
  GoRoute(
    path: Routes.reading,
    parentNavigatorKey: navigatorKey,
    pageBuilder: (context, state) => PdPage<void>(
      key: state.pageKey,
      fullscreenDialog: true,
      child: switch (state.extra) {
        final CaptureReadingArgs args => ReadingScreen(
          files: args.files,
          kind: args.kind,
          shared: shared,
        ),
        final List<PendingFile> files => ReadingScreen(
          files: files,
          shared: shared,
        ),
        _ => ReadingScreen(files: const [], shared: shared),
      },
    ),
  ),
  GoRoute(
    path: Routes.details,
    parentNavigatorKey: navigatorKey,
    pageBuilder: (context, state) => PdPage<void>(
      key: state.pageKey,
      fullscreenDialog: true,
      child: ItemFormScreen.create(
        state.extra is AddDetailsArgs
            ? state.extra! as AddDetailsArgs
            : const AddDetailsArgs(),
        shared: shared,
      ),
    ),
  ),
];
