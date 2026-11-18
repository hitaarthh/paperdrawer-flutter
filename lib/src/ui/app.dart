import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/vault_controller.dart';
import '../data/vault_record.dart';
import '../theme/drawer_theme.dart';
import 'design.dart';
import 'edit_record_page.dart';
import 'settings_page.dart';
import 'vault_page.dart';

class PaperDrawerApp extends StatelessWidget {
  const PaperDrawerApp({required this.vault, super.key});

  final VaultController vault;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider.value(
    value: vault,
    child: Selector<VaultController, VaultAppearance>(
      selector: (context, vault) => vault.themeMode,
      builder: (context, mode, child) => MaterialApp(
        title: 'PaperDrawer',
        debugShowCheckedModeBanner: false,
        theme: drawerTheme(Brightness.light),
        darkTheme: drawerTheme(Brightness.dark),
        themeMode: switch (mode) {
          VaultAppearance.system => ThemeMode.system,
          VaultAppearance.light => ThemeMode.light,
          VaultAppearance.dark => ThemeMode.dark,
        },
        home: const _DrawerShell(),
      ),
    ),
  );
}

class _DrawerShell extends StatefulWidget {
  const _DrawerShell();

  @override
  State<_DrawerShell> createState() => _DrawerShellState();
}

class _DrawerShellState extends State<_DrawerShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final colors = context.palette;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 21,
        title: const _Brand(),
        shape: Border(bottom: BorderSide(color: colors.line)),
      ),
      body: IndexedStack(
        index: _tab,
        children: const [VaultPage(), SettingsPage()],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.page,
          border: Border(top: BorderSide(color: colors.line)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 62,
            child: Row(
              children: [
                Expanded(
                  child: _Tab(
                    label: 'Vault',
                    icon: Icons.inventory_2_outlined,
                    selected: _tab == 0,
                    onTap: () => setState(() => _tab = 0),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: FilledButton.icon(
                      key: const ValueKey('add-item'),
                      onPressed: () => showAddEntry(context),
                      icon: const Icon(Icons.add, size: 19),
                      label: const Text('Add'),
                    ),
                  ),
                ),
                Expanded(
                  child: _Tab(
                    label: 'Settings',
                    icon: Icons.tune_rounded,
                    selected: _tab == 1,
                    onTap: () => setState(() => _tab = 1),
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

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      DrawerMark(fill: context.palette.marker, ink: context.palette.page),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          'PaperDrawer',
          style: displayStyle(context.palette.text, 23),
        ),
      ),
    ],
  );
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.palette;
    final color = selected ? colors.marker : colors.muted;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: SizedBox.expand(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
