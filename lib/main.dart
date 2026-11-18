import 'dart:io';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'app.dart';
import 'data/repositories/claim_repository.dart';
import 'data/repositories/item_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'data/services/app_database.dart';
import 'data/services/device_storage.dart';
import 'data/services/exporter.dart';
import 'data/services/file_store.dart';
import 'data/services/reminder_scheduler.dart';
import 'data/services/text_recognizer.dart';
import 'data/services/today.dart';
import 'ui/core/theme/tokens.dart';
import 'ui/core/widgets/icons.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Dark-only at launch: light status-bar content everywhere.
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  runApp(const _Bootstrap());
}

class _Opened {
  const _Opened(this.deps, this.database, this.launchLocation);

  final AppDependencies deps;
  final Database database;
  final String? launchLocation;
}

/// Opens the drawer (database, originals, reminders) before the app shows.
class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  late Future<_Opened> _opening = _open();

  Future<_Opened> _open() async {
    final support = await getApplicationSupportDirectory();
    // Same folder and file name as the first release, so its records migrate.
    final directory = Directory(p.join(support.path, 'paperdrawer'));
    await directory.create(recursive: true);
    await DeviceStorage.excludeFromBackup();

    final database = await AppDatabase.open(
      p.join(directory.path, 'vault.sqlite'),
    );
    try {
      final files = FileStore(directory);
      final items = ItemRepository(database, files);
      final claims = ClaimRepository(database);
      final settings = SettingsRepository(database);
      await Future.wait([items.load(), claims.load(), settings.load()]);

      final today = Today();
      final reminders = ReminderScheduler(
        gateway: FlutterLocalNotificationsGateway(),
        items: items,
        claims: claims,
        settings: settings,
        today: today,
      );
      String? launch;
      try {
        reminders.start();
        launch = await reminders.launchLocation();
      } catch (_) {
        // Reminders are a convenience; the drawer still opens without them.
      }

      return _Opened(
        AppDependencies(
          items: items,
          claims: claims,
          settings: settings,
          files: files,
          exporter: Exporter(files, today: today),
          recognizer: PlatformTextRecognizer(),
          today: today,
          reminders: reminders,
        ),
        database,
        launch,
      );
    } catch (_) {
      await database.close();
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _opening,
    builder: (context, snapshot) {
      final opened = snapshot.data;
      if (opened != null) {
        return PaperDrawerApp(
          deps: opened.deps,
          initialLocation: opened.launchLocation,
        );
      }
      return Directionality(
        textDirection: TextDirection.ltr,
        child: ColoredBox(
          color: Pd.bg,
          child: Center(
            child: snapshot.hasError
                ? _OpenError(
                    onRetry: () => setState(() => _opening = _open()),
                  )
                : const PaperDrawerMark(size: 40),
          ),
        ),
      );
    },
  );
}

class _OpenError extends StatelessWidget {
  const _OpenError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(Pd.s6),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const PaperDrawerMark(size: 40),
        const SizedBox(height: Pd.s6),
        const Text(
          'Your drawer didn’t open. Nothing is lost.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Pd.text, fontSize: 16, height: 1.5),
        ),
        const SizedBox(height: Pd.s4),
        GestureDetector(
          onTap: onRetry,
          behavior: HitTestBehavior.opaque,
          child: const Padding(
            padding: EdgeInsets.all(Pd.s3),
            child: Text(
              'Try again',
              style: TextStyle(
                color: Pd.lime,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
