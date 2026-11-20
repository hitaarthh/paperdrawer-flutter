import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/shared_profile.dart';

enum SharedSetting { leadDays, emailReminders }

typedef PendingSetting = ({String revision, String value});

class SettingsRepository extends ChangeNotifier {
  SettingsRepository(this._db, {this.syncsAccountSettings = false});

  static const leadDayChoices = [1, 3, 7, 14, 30];
  static const _reminders = 'reminders_on';
  static const _lead = 'lead_days';
  static const _email = 'email_reminders';
  static const _ticket = 'ticket_dismissed_key';
  static const _offered = 'reminders_offered';
  static const _name = 'profile_name';
  static const _plan = 'profile_plan';

  final Database _db;
  final bool syncsAccountSettings;
  Map<String, String> _values = {};
  Future<void> _pending = Future.value();
  bool _closed = false;

  List<int> get selectableLeadDays =>
      syncsAccountSettings ? SharedProfile.leadDayChoices : leadDayChoices;

  bool get remindersOn => _values[_reminders] == '1';
  bool get emailReminders => _values[_email] != '0';
  bool get onBasePlan => _values[_plan] != 'pro';
  String? get profileName => _values[_name];

  int get leadDays {
    final value = int.tryParse(_values[_lead] ?? '');
    return leadDayChoices.contains(value) ||
            (syncsAccountSettings &&
                SharedProfile.leadDayChoices.contains(value))
        ? value!
        : 7;
  }

  String? get ticketDismissedKey => _values[_ticket];

  /// True once the device reminder offer has been answered.
  bool get remindersOffered => _values[_offered] == '1';

  static String _key(SharedSetting field) => switch (field) {
    SharedSetting.leadDays => _lead,
    SharedSetting.emailReminders => _email,
  };

  static String _pendingKey(SharedSetting field) => 'pending:${_key(field)}';

  Map<SharedSetting, PendingSetting> get pendingSettings => {
    for (final field in SharedSetting.values)
      if (_values[_pendingKey(field)] case final revision?)
        field: (revision: revision, value: _values[_key(field)]!),
  };

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
    if (!selectableLeadDays.contains(value)) {
      return Future.error(
        const FormatException('Choose a reminder lead time.'),
      );
    }
    return _editShared(SharedSetting.leadDays, value.toString());
  }

  Future<void> setEmailReminders(bool value) =>
      _editShared(SharedSetting.emailReminders, value ? '1' : '0');

  Future<void> dismissTicket(String key) => _set(_ticket, key);

  Future<void> markRemindersOffered() => _set(_offered, '1');

  Future<void> eraseAll() => _write(() {
    if (!syncsAccountSettings) {
      return _apply({for (final key in _values.keys) key: null});
    }
    return _apply({_reminders: null, _ticket: null, _offered: null});
  });

  /// Apply server values only to clean fields or edits this response confirms.
  Future<void> mergeProfile(
    SharedProfile profile, {
    required Map<SharedSetting, PendingSetting> acknowledged,
  }) => _write(() {
    final incoming = {
      SharedSetting.leadDays: profile.leadDays.toString(),
      SharedSetting.emailReminders: profile.emailReminders ? '1' : '0',
    };
    final current = pendingSettings;
    final legacyLead =
        _values[_lead] != null &&
        !SharedProfile.leadDayChoices.contains(leadDays);
    return _apply({
      _name: profile.name,
      _plan: profile.onBasePlan ? 'base' : 'pro',
      for (final field in SharedSetting.values)
        if (!(field == SharedSetting.leadDays && legacyLead) &&
            (current[field] == null ||
                current[field] == acknowledged[field])) ...{
          _key(field): incoming[field],
          _pendingKey(field): null,
        },
    });
  });

  Future<void> _editShared(SharedSetting field, String value) => _write(() {
    final current = switch (field) {
      SharedSetting.leadDays => leadDays.toString(),
      SharedSetting.emailReminders => emailReminders ? '1' : '0',
    };
    if (current == value) return Future.value();
    return _apply({
      _key(field): value,
      if (syncsAccountSettings) _pendingKey(field): const Uuid().v4(),
    });
  });

  Future<void> _set(String key, String value) =>
      _write(() => _apply({key: value}));

  Future<void> _apply(Map<String, String?> changes) async {
    changes.removeWhere((key, value) => _values[key] == value);
    if (changes.isEmpty) return;
    await _db.transaction((txn) async {
      final batch = txn.batch();
      for (final entry in changes.entries) {
        final value = entry.value;
        if (value == null) {
          batch.delete('preferences', where: 'key = ?', whereArgs: [entry.key]);
        } else {
          batch.insert('preferences', {
            'key': entry.key,
            'value': value,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      await batch.commit(noResult: true);
    });
    for (final entry in changes.entries) {
      final value = entry.value;
      if (value == null) {
        _values.remove(entry.key);
      } else {
        _values[entry.key] = value;
      }
    }
    notifyListeners();
  }

  Future<void> _write(Future<void> Function() operation) {
    if (_closed) return Future.error(StateError('This drawer is closed.'));
    final result = _pending.then((_) => operation());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> finishWrites() {
    _closed = true;
    return _pending;
  }
}
