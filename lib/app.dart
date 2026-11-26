import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'data/repositories/item_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'data/services/account_settings_sync.dart';
import 'data/services/capture_service.dart';
import 'data/services/drawer_actions.dart';
import 'data/services/exporter.dart';
import 'data/services/file_store.dart';
import 'data/services/legacy_claims.dart';
import 'data/services/reminder_scheduler.dart';
import 'data/services/text_recognizer.dart';
import 'data/services/today.dart';
import 'routing/router.dart';
import 'ui/core/theme/app_theme.dart';
import 'ui/features/account/drawer_account_actions.dart';
import 'ui/features/shell/tab_reselect.dart';

/// Everything the app needs, opened once at startup by `main.dart` (or by a
/// test with in-memory fakes).
class AppDependencies {
  const AppDependencies({
    required this.items,
    required this.legacyClaims,
    required this.settings,
    required this.files,
    required this.exporter,
    required this.recognizer,
    required this.today,
    this.capture = const CaptureService(),
    this.actions = const DrawerActions(),
    this.reminders,
    this.settingsSync,
  });

  final ItemRepository items;

  /// Rows the removed claims feature left behind; only export and "Clear
  /// this drawer" use them.
  final LegacyClaims legacyClaims;
  final SettingsRepository settings;
  final FileStore files;
  final Exporter exporter;
  final TextRecognizer recognizer;
  final Today today;
  final CaptureService capture;
  final DrawerActions actions;

  /// Null in widget tests, where no notification plugin is available.
  final ReminderScheduler? reminders;
  final AccountSettingsSync? settingsSync;
}

class PaperDrawerApp extends StatefulWidget {
  const PaperDrawerApp({
    required this.deps,
    this.initialLocation,
    this.account,
    super.key,
  });

  final AppDependencies deps;
  final String? initialLocation;
  final DrawerAccountActions? account;

  @override
  State<PaperDrawerApp> createState() => _PaperDrawerAppState();
}

class _PaperDrawerAppState extends State<PaperDrawerApp>
    with WidgetsBindingObserver {
  late final GoRouter _router = buildRouter(
    initialLocation: widget.initialLocation,
  );
  final _reselect = TabReselect();
  StreamSubscription<String>? _taps;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.deps.settingsSync?.resume();
    // A tapped reminder opens the item it is about.
    _taps = widget.deps.reminders?.taps.listen(_router.go);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.deps.settingsSync?.resume();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      widget.deps.settingsSync?.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.deps.settingsSync?.pause();
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
        Provider<DrawerAccountActions?>.value(value: widget.account),
        ChangeNotifierProvider.value(value: deps.items),
        ChangeNotifierProvider.value(value: deps.settings),
        ChangeNotifierProvider.value(value: deps.today),
        ChangeNotifierProvider.value(value: _reselect),
        Provider.value(value: deps.files),
        Provider.value(value: deps.exporter),
        Provider<LegacyClaims>.value(value: deps.legacyClaims),
        Provider.value(value: deps.recognizer),
        Provider.value(value: deps.capture),
        Provider.value(value: deps.actions),
        Provider<ReminderScheduler?>.value(value: deps.reminders),
      ],
      child: MaterialApp.router(
        title: 'Paper Drawer',
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
