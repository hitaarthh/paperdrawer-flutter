import 'lead_days.dart';
import 'notification_kind.dart';
import 'notification_preferences.dart';
import 'reminder_time.dart';

/// [NotificationPreferences] as rows of the keyed `settings` table
/// (`settings(key, value, updated_at, dirty)`, schema v7).
///
/// Every key here is a *synced* setting (it follows the account to its other
/// devices). Device-only state, such as the iOS permission, is not part of
/// the preferences.
///
/// Keys (`<kind>` is `NotificationKind.name`):
/// - `notifications.<kind>.on`: `1` | `0`
/// - `notifications.<kind>.lead_days`: `30,7,0` (deadline kinds only)
/// - `notifications.<kind>.push`: `1` | `0`
/// - `notifications.<kind>.email`: `1` | `0`
/// - `notifications.time_of_day`: `HH:mm`
/// - `notifications.last_day_repeat`: `1` | `0`
/// - `notifications.last_day_time_sensitive`: `1` | `0`
/// - `notifications.lock_screen`: `show_names` | `hide_details`
/// - `notifications.email_copies`: `1` | `0`
abstract final class NotificationSettingsCodec {
  static const prefix = 'notifications.';
  static const timeOfDayKey = '${prefix}time_of_day';
  static const lastDayRepeatKey = '${prefix}last_day_repeat';
  static const timeSensitiveKey = '${prefix}last_day_time_sensitive';
  static const lockScreenKey = '${prefix}lock_screen';
  static const emailCopiesKey = '${prefix}email_copies';

  static String onKey(NotificationKind kind) => '$prefix${kind.name}.on';
  static String leadDaysKey(NotificationKind kind) =>
      '$prefix${kind.name}.lead_days';
  static String pushKey(NotificationKind kind) => '$prefix${kind.name}.push';
  static String emailKey(NotificationKind kind) => '$prefix${kind.name}.email';

  /// Every key [encode] writes, in a stable order.
  static List<String> get keys => [
    for (final kind in NotificationKind.values) ...[
      onKey(kind),
      if (kind.isDeadline) leadDaysKey(kind),
      pushKey(kind),
      emailKey(kind),
    ],
    timeOfDayKey,
    lastDayRepeatKey,
    timeSensitiveKey,
    lockScreenKey,
    emailCopiesKey,
  ];

  static Map<String, String> encode(NotificationPreferences preferences) => {
    for (final kind in NotificationKind.values) ...{
      onKey(kind): _flag(preferences[kind].on),
      if (kind.isDeadline)
        leadDaysKey(kind): encodeLeadDays(preferences[kind].leadDays),
      pushKey(kind): _flag(preferences[kind].push),
      emailKey(kind): _flag(preferences[kind].email),
    },
    timeOfDayKey: preferences.timeOfDay.stored,
    lastDayRepeatKey: _flag(preferences.lastDayRepeat),
    timeSensitiveKey: _flag(preferences.timeSensitiveLastDay),
    lockScreenKey: _lockScreen(preferences.lockScreen),
    emailCopiesKey: _flag(preferences.emailCopies),
  };

  /// Reads preferences from [settings]. Missing keys keep their defaults; a
  /// malformed value also keeps its default and its key is reported in
  /// [DecodedNotificationSettings.invalidKeys] (so the data layer can log the
  /// key, never the value, and rewrite it).
  static DecodedNotificationSettings decode(Map<String, String> settings) {
    final invalid = <String>[];
    var preferences = NotificationPreferences.defaults();

    bool? flag(String key) {
      final value = settings[key];
      if (value == null) return null;
      if (value == '1') return true;
      if (value == '0') return false;
      invalid.add(key);
      return null;
    }

    for (final kind in NotificationKind.values) {
      final defaults = preferences[kind];
      final on = flag(onKey(kind)) ?? defaults.on;
      final push = flag(pushKey(kind)) ?? defaults.push;
      final email = flag(emailKey(kind)) ?? defaults.email;
      var lead = defaults.leadDays;
      final storedLead = kind.isDeadline ? settings[leadDaysKey(kind)] : null;
      if (storedLead != null) {
        final decoded = decodeLeadDays(storedLead);
        if (decoded == null) {
          invalid.add(leadDaysKey(kind));
        } else {
          lead = decoded;
        }
      }
      final changed = preferences.withKind(
        kind,
        on: on,
        leadDays: lead,
        push: push,
        email: email,
      );
      final value = changed.valueOrNull;
      if (value != null) {
        preferences = value;
      } else {
        // On with no lead time (or a mix that doesn't validate): keep the
        // kind's default rather than silently switching it off.
        invalid.add(leadDaysKey(kind));
      }
    }

    final time = settings[timeOfDayKey];
    if (time != null) {
      final parsed = ReminderTime.parse(time).valueOrNull;
      if (parsed == null) {
        invalid.add(timeOfDayKey);
      } else {
        preferences = preferences.withShared(timeOfDay: parsed);
      }
    }
    final lock = settings[lockScreenKey];
    LockScreenDetail? lockScreen;
    if (lock != null) {
      lockScreen = _parseLockScreen(lock);
      if (lockScreen == null) invalid.add(lockScreenKey);
    }
    preferences = preferences.withShared(
      lastDayRepeat: flag(lastDayRepeatKey),
      timeSensitiveLastDay: flag(timeSensitiveKey),
      lockScreen: lockScreen,
      emailCopies: flag(emailCopiesKey),
    );
    return DecodedNotificationSettings(
      preferences,
      List.unmodifiable(invalid.toSet().toList()..sort()),
    );
  }

  /// design-v1's preferences as the new ones.
  ///
  /// [legacyLeadDays] is the stored `lead_days` row, or `null` when the user
  /// never chose one (then every kind keeps the new defaults). A chosen value
  /// N becomes `[N]` for every deadline kind (2 becomes 3, see
  /// [migrateLegacyLeadDays]); on/off per kind keeps its default.
  /// [legacyEmailReminders] is `email_reminders` (`null` keeps the default).
  static NotificationPreferences fromLegacy({
    int? legacyLeadDays,
    bool? legacyEmailReminders,
  }) {
    var preferences = NotificationPreferences.defaults().withShared(
      emailCopies: legacyEmailReminders,
    );
    if (legacyLeadDays == null) return preferences;
    final lead = migrateLegacyLeadDays(legacyLeadDays);
    for (final kind in NotificationKind.deadlines) {
      // [lead] is always a valid choice, so this never fails.
      preferences =
          preferences.withKind(kind, leadDays: [lead]).valueOrNull ??
          preferences;
    }
    return preferences;
  }

  static String _flag(bool value) => value ? '1' : '0';

  static String _lockScreen(LockScreenDetail detail) => switch (detail) {
    LockScreenDetail.showNames => 'show_names',
    LockScreenDetail.hideDetails => 'hide_details',
  };

  static LockScreenDetail? _parseLockScreen(String value) {
    for (final detail in LockScreenDetail.values) {
      if (_lockScreen(detail) == value) return detail;
    }
    return null;
  }
}

/// The result of [NotificationSettingsCodec.decode].
final class DecodedNotificationSettings {
  const DecodedNotificationSettings(this.preferences, this.invalidKeys);

  final NotificationPreferences preferences;

  /// Keys whose stored value could not be used (sorted, unique).
  final List<String> invalidKeys;
}
