import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

import '../../../data/repositories/claim_repository.dart';
import '../../../data/repositories/item_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../data/services/drawer_actions.dart';
import '../../../data/services/exporter.dart';
import '../../../data/services/reminder_scheduler.dart';
import '../reminders/reminder_permission.dart';

class SettingsViewModel extends ChangeNotifier {
  SettingsViewModel(
    this._settings,
    this._items,
    this._claims,
    this._exporter,
    this._actions,
    this._reminders,
  ) {
    _settings.addListener(notifyListeners);
    _items.addListener(notifyListeners);
  }

  final SettingsRepository _settings;
  final ItemRepository _items;
  final ClaimRepository _claims;
  final Exporter _exporter;
  final DrawerActions _actions;
  final ReminderScheduler? _reminders;
  bool _disposed = false;
  bool busy = false;
  String? error;

  late final Future<String?> version = _actions.appVersion();
  bool get remindersOn => _settings.remindersOn;
  bool get canRemind => _reminders != null;
  int get leadDays => _settings.leadDays;
  int get active => _items.activeCount;
  int get archived => _items.archived.length;

  Future<bool> setReminders(bool value) => _run(() async {
    if (!value) return _settings.setRemindersOn(false);
    if (!await turnOnReminders(_reminders, _settings)) {
      throw const FormatException(
        'Allow notifications for Paper Drawer in your device settings to turn on reminders.',
      );
    }
  }, 'Reminders couldn’t be updated. Try again.');

  Future<bool> setLeadDays(int days) => _run(
    () => _settings.setLeadDays(days),
    'Reminder timing couldn’t be updated. Try again.',
  );

  Future<bool> export(Rect? origin) => _run(() async {
    final file = await _exporter.exportEverything(
      items: _items.items,
      claims: _claims.claims,
    );
    try {
      await _actions.shareFiles([XFile(file.path)], origin: origin);
    } finally {
      await _exporter.discardExport(file);
    }
  }, 'Your drawer couldn’t be exported. Try again.');

  Future<bool> erase() => _run(() async {
    await _items.eraseAll();
    await _claims.eraseAll();
    await _settings.eraseAll();
  }, 'The drawer couldn’t be cleared. Try again.');

  Future<bool> _run(Future<void> Function() operation, String fallback) async {
    if (busy) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await operation();
      return true;
    } on FormatException catch (failure) {
      error = failure.message;
    } catch (_) {
      error = fallback;
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
    return false;
  }

  @override
  void dispose() {
    _disposed = true;
    _settings.removeListener(notifyListeners);
    _items.removeListener(notifyListeners);
    super.dispose();
  }
}
