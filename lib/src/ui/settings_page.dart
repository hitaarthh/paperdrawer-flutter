import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/vault_controller.dart';
import '../data/vault_record.dart';
import '../theme/drawer_theme.dart';
import 'design.dart';
import 'vault_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final vault = context.watch<VaultController>();
    final colors = context.palette;
    return DrawerPage(
      children: [
        Text('Settings', style: displayStyle(colors.text, 46)),
        const SizedBox(height: 22),
        Text('APPEARANCE', style: monoLabel(colors.marker)),
        const SizedBox(height: 9),
        PaperPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Choose how PaperDrawer looks.'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  for (final mode in VaultAppearance.values)
                    ChoiceChip(
                      label: Text(switch (mode) {
                        VaultAppearance.system => 'System',
                        VaultAppearance.light => 'Light',
                        VaultAppearance.dark => 'Dark',
                      }),
                      selected: vault.themeMode == mode,
                      onSelected: (selected) async {
                        if (!selected) return;
                        try {
                          await vault.setTheme(mode);
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Couldn’t save your appearance setting.',
                                ),
                              ),
                            );
                          }
                        }
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('STORAGE', style: monoLabel(colors.marker)),
        const SizedBox(height: 9),
        const PaperPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.lock_outline, size: 19),
                  SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'On this device',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                'Your vault is stored on this device. Removing the app can erase it.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        PaperPanel(
          padding: EdgeInsets.zero,
          child: ListTile(
            leading: const Icon(Icons.archive_outlined),
            title: const Text('Archive'),
            subtitle: Text('${vault.archive.length} archived'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const _ArchivePage()),
            ),
          ),
        ),
      ],
    );
  }
}

class _ArchivePage extends StatelessWidget {
  const _ArchivePage();

  @override
  Widget build(BuildContext context) {
    final archived = context.watch<VaultController>().archive;
    return Scaffold(
      appBar: AppBar(title: const Text('Archive')),
      body: DrawerPage(
        children: [
          if (archived.isEmpty)
            const PaperPanel(child: Text('Archived items will appear here.')),
          for (final record in archived)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RecordTile(record: record),
            ),
        ],
      ),
    );
  }
}
