import 'package:flutter/foundation.dart';

import '../../../data/repositories/settings_repository.dart';
import '../../../data/services/reminder_scheduler.dart';
import 'reminder_permission.dart';

/// State for the "Turn on reminders" offer.
class RemindersViewModel extends ChangeNotifier {
  RemindersViewModel(this._settings, this._scheduler);

  final SettingsRepository _settings;
  final ReminderScheduler? _scheduler;
  bool _disposed = false;

  bool busy = false;

  /// Set when the user said no at the iOS prompt.
  bool denied = false;
  String? error;

  /// How far ahead reminders arrive, in words ("a week").
  String get leadPhrase => switch (_settings.leadDays) {
    1 => 'a day',
    7 => 'a week',
    14 => 'two weeks',
    30 => 'a month',
    final days => '$days days',
  };

  /// Asks for permission. Returns true when reminders are now on.
  Future<bool> turnOn() async {
    if (busy) return false;
    busy = true;
    error = null;
    _notify();
    try {
      final granted = await turnOnReminders(_scheduler, _settings);
      denied = !granted;
      return granted;
    } catch (_) {
      error =
          'Reminders couldn’t be turned on. You can try again from Settings.';
      return false;
    } finally {
      busy = false;
      _notify();
    }
  }

  /// "Not now": remember the answer so the offer never shows again.
  Future<void> notNow() async {
    try {
      await _settings.markRemindersOffered();
    } catch (_) {
      // At worst the offer appears once more after a later save.
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
