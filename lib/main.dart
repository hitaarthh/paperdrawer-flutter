import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'data/services/device_storage.dart';
import 'data/services/drawer_storage.dart';
import 'data/services/shared_account.dart';
import 'drawer_runtime.dart';
import 'ui/core/theme/tokens.dart';
import 'ui/core/widgets/button.dart';
import 'ui/core/widgets/icons.dart';
import 'ui/features/account/shared_app.dart';
import 'ui/features/intro/app_opening.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  runApp(const _Bootstrap());
}

typedef _Opened = ({
  DrawerStorage storage,
  SharedAccount? account,
  DrawerRuntime? runtime,
  String? launchLocation,
});

class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  late Future<_Opened> _opening = _open();

  Future<_Opened> _open() async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory(p.join(support.path, 'paperdrawer'));
    await directory.create(recursive: true);
    await DeviceStorage.excludeFromBackup();
    final storage = DrawerStorage(directory);
    if (SharedAccountConfig.requested) {
      final account = await SharedAccount.open(
        SharedAccountConfig.fromEnvironment(),
      );
      return (
        storage: storage,
        account: account,
        runtime: null,
        launchLocation: null,
      );
    }
    final runtime = DrawerRuntime(await storage.open());
    return (
      storage: storage,
      account: null,
      runtime: runtime,
      launchLocation: await runtime.launchLocation(),
    );
  }

  @override
  void dispose() {
    unawaited(
      _opening.then(
        (opened) => opened.runtime?.close(),
        onError: (Object _, StackTrace _) {},
      ),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppOpening(
    opening: _opening,
    appBuilder: (opened) => switch (opened.account) {
      final account? => AccountDrawerApp(
        account: account,
        storage: opened.storage,
      ),
      null => PaperDrawerApp(
        deps: opened.runtime!.deps,
        initialLocation: opened.launchLocation,
      ),
    },
    errorBuilder: (error) => Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: Pd.bg,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(Pd.margin),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: Pd.s4,
              children: [
                const PaperDrawerMark(size: 40),
                Text(
                  error is FormatException
                      ? error.message
                      : 'Your drawer didn’t open. Try again.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Pd.text),
                ),
                PdButton.text(
                  label: 'Try again',
                  onPressed: () => setState(() => _opening = _open()),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
