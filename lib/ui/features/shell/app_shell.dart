import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../data/services/today.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/tab_bar.dart';
import '../add/add_flow.dart';
import 'tab_reselect.dart';

/// Hosts Home, Vault and Settings with the Add action. Pushed screens inside a
/// tab keep the dock; full-screen add and edit flows cover it.
class AppShell extends StatefulWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Days left are counted from the local date, which may have moved on
    // while the app was in the background.
    if (state == AppLifecycleState.resumed) context.read<Today>().refresh();
  }

  void _select(int index) {
    final shell = widget.navigationShell;
    final again = index == shell.currentIndex;
    shell.goBranch(index, initialLocation: again);
    if (again) context.read<TabReselect>().fire(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Pd.bg,
      extendBody: true,
      body: widget.navigationShell,
      bottomNavigationBar: PdTabBar(
        currentIndex: widget.navigationShell.currentIndex,
        onTap: _select,
        onScan: () => AddFlow.manual(context),
        homeFirst: true,
      ),
    );
  }
}
