import 'package:flutter/material.dart' show LicensePage;
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../data/services/drawer_actions.dart';
import '../../../routing/router.dart';
import '../../core/widgets/list_row.dart';
import '../../core/widgets/nav.dart';
import '../../core/widgets/snackbar.dart';

class LegalSettingsScreen extends StatelessWidget {
  const LegalSettingsScreen({super.key});

  static const _host = 'www.paperdrawer.app';

  Future<void> _open(BuildContext context, String path) async {
    try {
      await const DrawerActions().openLink(Uri.https(_host, path));
    } catch (_) {
      if (context.mounted) showPdSnackbar(context, 'Couldn’t open the link. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) => PdPushedScaffold(
    title: 'Legal & about',
    backLabel: 'Settings',
    glassBack: true,
    onBack: () => context.canPop() ? context.pop() : context.go(Routes.settings),
    children: [
      PdListGroup(
        children: [
          PdListRow(title: 'Privacy Policy', chevron: true, onTap: () => _open(context, '/privacy')),
          PdListRow(title: 'Terms of Service', chevron: true, onTap: () => _open(context, '/terms')),
          PdListRow(title: 'Open-source licenses', chevron: true, onTap: () => context.push(Routes.licenses)),
          PdListRow(title: 'Paper Drawer website', chevron: true, onTap: () => _open(context, '/')),
        ],
      ),
    ],
  );
}

List<GoRoute> legalRoutes(GlobalKey<NavigatorState> navigatorKey) => [
  GoRoute(
    path: 'legal',
    parentNavigatorKey: navigatorKey,
    builder: (context, state) => const LegalSettingsScreen(),
    routes: [
      GoRoute(
        path: 'licenses',
        builder: (context, state) => const LicensePage(applicationName: 'Paper Drawer'),
      ),
    ],
  ),
];
