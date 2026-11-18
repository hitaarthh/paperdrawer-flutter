import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

class SettingsRepository extends ChangeNotifier {
  SettingsRepository(this._db);

  static const leadDayChoices = [1, 3, 7, 14, 30];
  static const _reminders = 'reminders_on';
  static const _lead = 'lead_days';
  static const _ticket = 'ticket_dismissed_key';

  final Database _db;
  Map<String, String> _values = {};
  Future<void> _pending = Future.value();

  bool get remindersOn => _values[_reminders] == '1';
  int get leadDays {
    final value = int.tryParse(_values[_lead] ?? '');
    return leadDayChoices.contains(value) ? value! : 7;
  }

  String? get ticketDismissedKey => _values[_ticket];

  Future<void> load() async {
    _values = {
      for (final row in await _db.query('preferences'))
        row['key']! as String: row['value']! as String,
    };
    notifyListeners();
  }

  Future<void> setRemindersOn(bool value) =>
      _set(_reminders, value ? '1' : '0');
  Future<void> setLeadDays(int value) {
    if (!leadDayChoices.contains(value)) {
      return Future.error(
        const FormatException('Choose a reminder lead time.'),
      );
    }
    return _set(_lead, value.toString());
  }

  Future<void> dismissTicket(String key) => _set(_ticket, key);

  Future<void> eraseAll() => _write(() async {
    await _db.delete('preferences');
    _values.clear();
  });

  Future<void> _set(String key, String value) => _write(() async {
    await _db.insert('preferences', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    _values[key] = value;
  });

  Future<void> _write(Future<void> Function() operation) {
    final result = _pending.then((_) async {
      await operation();
      notifyListeners();
    });
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }
}
