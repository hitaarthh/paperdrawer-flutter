import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../../data/services/drawer_actions.dart';
import '../../../routing/router.dart';
import '../../../routing/paper_page.dart';
import '../../core/widgets/list_row.dart';
import '../../core/widgets/snackbar.dart';
import 'shared_settings_widgets.dart';

class LegalSettingsScreen extends StatelessWidget {
  const LegalSettingsScreen({super.key});

  static const _host = 'www.paperdrawer.app';

  Future<void> _open(BuildContext context, String path) async {
    try {
      await const DrawerActions().openLink(Uri.https(_host, path));
    } catch (_) {
      if (context.mounted) {
        showPdSnackbar(context, 'Couldn’t open the link. Try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => SettingsSubpage(
    title: 'Legal',
    children: [
      SettingsMenu(
        children: [
          PdListRow(
            title: 'Privacy Policy',
            leadingIcon: LucideIcons.shield,
            chevron: true,
            onTap: () => _open(context, '/privacy'),
          ),
          PdListRow(
            title: 'Terms of Service',
            leadingIcon: LucideIcons.fileText,
            chevron: true,
            onTap: () => _open(context, '/terms'),
          ),
          PdListRow(
            title: 'Open-source licenses',
            leadingIcon: LucideIcons.bookOpen,
            chevron: true,
            onTap: () => context.push(Routes.licenses),
          ),
          PdListRow(
            title: 'Paper Drawer website',
            leadingIcon: LucideIcons.globe,
            chevron: true,
            onTap: () => _open(context, '/'),
          ),
        ],
      ),
    ],
  );
}

List<GoRoute> legalRoutes(GlobalKey<NavigatorState> navigatorKey) => [
  GoRoute(
    path: 'legal',
    parentNavigatorKey: navigatorKey,
    pageBuilder: (context, state) =>
        PdPage<void>(key: state.pageKey, child: const LegalSettingsScreen()),
    routes: [
      GoRoute(
        path: 'licenses',
        pageBuilder: (context, state) => PdPage<void>(
          key: state.pageKey,
          child: const LicensePage(applicationName: 'Paper Drawer'),
        ),
      ),
    ],
  ),
];
