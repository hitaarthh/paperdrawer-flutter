import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'data/repositories/claim_repository.dart';
import 'data/repositories/item_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'data/services/capture_service.dart';
import 'data/services/drawer_actions.dart';
import 'data/services/exporter.dart';
import 'data/services/file_store.dart';
import 'data/services/reminder_scheduler.dart';
import 'data/services/text_recognizer.dart';
import 'data/services/today.dart';
import 'routing/router.dart';
import 'ui/core/theme/app_theme.dart';
import 'ui/features/shell/tab_reselect.dart';

/// Everything the app needs, opened once at startup by `main.dart` (or by a
/// test with in-memory fakes).
class AppDependencies {
  const AppDependencies({
    required this.items,
    required this.claims,
    required this.settings,
    required this.files,
    required this.exporter,
    required this.recognizer,
    required this.today,
    this.capture = const CaptureService(),
    this.actions = const DrawerActions(),
    this.reminders,
  });

  final ItemRepository items;
  final ClaimRepository claims;
  final SettingsRepository settings;
  final FileStore files;
  final Exporter exporter;
  final TextRecognizer recognizer;
  final Today today;
  final CaptureService capture;
  final DrawerActions actions;

  /// Null in widget tests, where no notification plugin is available.
  final ReminderScheduler? reminders;
}

class PaperDrawerApp extends StatefulWidget {
  const PaperDrawerApp({
    required this.deps,
    this.initialLocation,
    super.key,
  });

  final AppDependencies deps;
  final String? initialLocation;

  @override
  State<PaperDrawerApp> createState() => _PaperDrawerAppState();
}

class _PaperDrawerAppState extends State<PaperDrawerApp> {
  late final GoRouter _router = buildRouter(
    initialLocation: widget.initialLocation,
  );
  final _reselect = TabReselect();
  StreamSubscription<String>? _taps;

  @override
  void initState() {
    super.initState();
    // A tapped reminder opens the item or claim it is about.
    _taps = widget.deps.reminders?.taps.listen(_router.go);
  }

  @override
  void dispose() {
    _taps?.cancel();
    _router.dispose();
    _reselect.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deps = widget.deps;
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: deps.items),
        ChangeNotifierProvider.value(value: deps.claims),
        ChangeNotifierProvider.value(value: deps.settings),
        ChangeNotifierProvider.value(value: deps.today),
        ChangeNotifierProvider.value(value: _reselect),
        Provider.value(value: deps.files),
        Provider.value(value: deps.exporter),
        Provider.value(value: deps.recognizer),
        Provider.value(value: deps.capture),
        Provider.value(value: deps.actions),
        Provider<ReminderScheduler?>.value(value: deps.reminders),
      ],
      child: MaterialApp.router(
        title: 'PaperDrawer',
        debugShowCheckedModeBanner: false,
        theme: pdTheme(),
        themeMode: ThemeMode.dark,
        routerConfig: _router,
        builder: (context, child) {
          // Support Dynamic Type up to 200%; cards grow taller, never clip.
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(
              textScaler: media.textScaler.clamp(maxScaleFactor: 2),
            ),
            child: child!,
          );
        },
      ),
    );
  }
}
