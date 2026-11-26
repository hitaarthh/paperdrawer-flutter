import 'app.dart';
import 'data/services/account_settings_sync.dart';
import 'data/services/drawer_storage.dart';
import 'data/services/exporter.dart';
import 'data/services/reminder_scheduler.dart';
import 'data/services/text_recognizer.dart';
import 'data/services/today.dart';

/// Owns the dependencies of one mounted drawer and releases them in order.
class DrawerRuntime {
  DrawerRuntime(
    this.drawer, {
    DrawerOwner? owner,
    AccountSettingsRemote? remote,
  }) {
    final today = Today();
    final reminders = ReminderScheduler(
      gateway: FlutterLocalNotificationsGateway(),
      items: drawer.items,
      settings: drawer.settings,
      today: today,
      accountScope: owner?.key,
    );
    deps = AppDependencies(
      items: drawer.items,
      legacyClaims: drawer.legacyClaims,
      settings: drawer.settings,
      files: drawer.files,
      exporter: Exporter(drawer.files, today: today),
      recognizer: PlatformTextRecognizer(),
      today: today,
      reminders: reminders,
      settingsSync: remote == null
          ? null
          : AccountSettingsSync(drawer.settings, remote),
    );
    reminders.start();
  }

  final LocalDrawer drawer;
  late final AppDependencies deps;
  Future<void>? _closing;

  Future<String?> launchLocation() async {
    try {
      return await deps.reminders?.launchLocation();
    } catch (_) {
      return null;
    }
  }

  void stopSync() => deps.settingsSync?.dispose();

  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    stopSync();
    try {
      await deps.reminders?.close();
    } catch (_) {
      // Notification availability should not prevent closing a drawer.
    } finally {
      deps.today.dispose();
      await drawer.close();
    }
  }
}
