import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'src/data/sqlite_vault_repository.dart';
import 'src/data/vault_controller.dart';
import 'src/theme/drawer_theme.dart';
import 'src/ui/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _Bootstrap());
}

class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  late Future<VaultController> _loading = _openVault();

  Future<VaultController> _openVault() async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory(p.join(support.path, 'paperdrawer'));
    await directory.create(recursive: true);
    if (Platform.isIOS) {
      const storage = MethodChannel('app.paperdrawer.mobile/storage');
      await storage.invokeMethod<void>('excludeFromBackup');
    }
    final repository = await SqliteVaultRepository.open(directory);
    try {
      final controller = VaultController(repository);
      await controller.initialize();
      return controller;
    } catch (_) {
      await repository.close();
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _loading,
    builder: (context, snapshot) {
      final vault = snapshot.data;
      if (vault != null) return PaperDrawerApp(vault: vault);
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'PaperDrawer',
        theme: drawerTheme(Brightness.light),
        darkTheme: drawerTheme(Brightness.dark),
        home: Scaffold(
          body: Center(
            child: snapshot.hasError
                ? FilledButton(
                    onPressed: () => setState(() => _loading = _openVault()),
                    child: const Text('Couldn’t open the vault · Retry'),
                  )
                : const CircularProgressIndicator(),
          ),
        ),
      );
    },
  );
}
