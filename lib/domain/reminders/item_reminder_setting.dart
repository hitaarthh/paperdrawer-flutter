import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/failure/app_failure.dart';
import '../../core/failure/validation_issue.dart';
import '../../core/result/result.dart';
import '../../core/time/clock.dart';
import 'lead_days.dart';
import 'notification_kind.dart';
import 'notification_preferences.dart';
import 'reminder_time.dart';

/// How one item is reminded: Item › Reminders ("My defaults", "Custom",
/// "Muted"). Stored per item; see [encode] / [decode].
@immutable
sealed class ItemReminderSetting {
  const ItemReminderSetting();

  /// "My defaults": the item follows Settings › Notifications.
  static const defaults = ItemRemindersDefault();

  /// "Muted keeps the dates in your vault without any notifications."
  static const muted = ItemRemindersMuted();

  /// "Custom": this item's own lead times per window. A kind missing from
  /// [leadDays] follows the defaults; an empty list means no reminders for
  /// that window. [once] is a one-off reminder at a chosen date and time
  /// (design-v1's `reminder_at`).
  ///
  /// Fails with `ValidationFailure(leadTimeInvalid, field: kind.name)` for a
  /// lead time outside `NotificationKind.leadDayChoices` or a kind that is
  /// not a deadline.
  static Result<ItemReminderSetting> custom(
    Map<NotificationKind, List<int>> leadDays, {
    OnceReminder? once,
  }) {
    final normalised = <NotificationKind, List<int>>{};
    for (final MapEntry(:key, :value) in leadDays.entries) {
      final lead = key.isDeadline ? normaliseLeadDays(value) : null;
      if (lead == null) {
        return Err<ItemReminderSetting>(
          ValidationFailure(ValidationIssue.leadTimeInvalid, field: key.name),
        );
      }
      normalised[key] = lead;
    }
    return Ok(ItemRemindersCustom._(Map.unmodifiable(normalised), once));
  }

  /// design-v1's columns as a setting: `remind = 0` is muted; a
  /// `reminder_at` becomes a custom one-off at that local wall-clock time,
  /// with no lead-time reminders (design-v1 sent only that one).
  ///
  /// [reminderAtLocal] must already be in the device's zone (the data layer
  /// converts the stored epoch milliseconds); only its fields are read.
  factory ItemReminderSetting.fromLegacy({
    required bool remind,
    DateTime? reminderAtLocal,
  }) {
    if (!remind) return muted;
    if (reminderAtLocal == null) return defaults;
    return ItemRemindersCustom._(
      {for (final kind in NotificationKind.deadlines) kind: const <int>[]},
      OnceReminder(
        civilDate(reminderAtLocal),
        ReminderTime.ofInstant(reminderAtLocal),
      ),
    );
  }

  bool get isMuted => this is ItemRemindersMuted;

  /// The lead times this item uses for [kind], or an empty list for none.
  ///
  /// Muted: none. Custom with [kind]: its own list (even when the kind is
  /// off in Settings; the user chose it for this item). Otherwise the
  /// preference's list when [kind] is on there.
  List<int> leadDaysFor(
    NotificationKind kind,
    NotificationPreferences preferences,
  ) {
    final setting = preferences[kind];
    final fallback = setting.on ? setting.leadDays : const <int>[];
    return switch (this) {
      ItemRemindersMuted() => const [],
      ItemRemindersDefault() => fallback,
      ItemRemindersCustom(:final leadDays) => leadDays[kind] ?? fallback,
    };
  }

  /// The stored JSON form (`items.reminder_setting`, schema v7):
  /// `{"v":1,"mode":"defaults"}`, `{"v":1,"mode":"muted"}` or
  /// `{"v":1,"mode":"custom","lead":{"returnWindow":[3,0]},"once":"2026-11-27T09:00"}`.
  String encode() => jsonEncode(switch (this) {
    ItemRemindersDefault() => {'v': 1, 'mode': 'defaults'},
    ItemRemindersMuted() => {'v': 1, 'mode': 'muted'},
    ItemRemindersCustom(:final leadDays, :final once) => {
      'v': 1,
      'mode': 'custom',
      'lead': {
        for (final kind in NotificationKind.deadlines)
          if (leadDays[kind] case final lead?) kind.name: lead,
      },
      if (once != null) 'once': once.stored,
    },
  });

  /// Parses [encode]'s form. `null` or an empty string is "My defaults".
  ///
  /// Fails with `ValidationFailure(settingInvalid)` for anything else that
  /// does not parse, so the data layer can report the row and keep the
  /// defaults.
  static Result<ItemReminderSetting> decode(String? stored) {
    if (stored == null || stored.trim().isEmpty) return const Ok(defaults);
    const invalid = Err<ItemReminderSetting>(
      ValidationFailure(ValidationIssue.settingInvalid, field: 'reminders'),
    );
    final json = _tryDecodeJson(stored);
    if (json is! Map<String, Object?> || json['v'] != 1) return invalid;
    switch (json['mode']) {
      case 'defaults':
        return const Ok(defaults);
      case 'muted':
        return const Ok(muted);
      case 'custom':
        final lead = json['lead'];
        if (lead is! Map<String, Object?>) return invalid;
        final parsed = <NotificationKind, List<int>>{};
        for (final MapEntry(:key, :value) in lead.entries) {
          final kind = _kindNamed(key);
          if (kind == null || value is! List<Object?>) return invalid;
          final days = value.whereType<int>().toList();
          if (days.length != value.length) return invalid;
          parsed[kind] = days;
        }
        final onceValue = json['once'];
        OnceReminder? once;
        if (onceValue != null) {
          once = onceValue is String ? OnceReminder.parse(onceValue) : null;
          if (once == null) return invalid;
        }
        return switch (custom(parsed, once: once)) {
          Ok(:final value) => Ok(value),
          Err() => invalid,
        };
      default:
        return invalid;
    }
  }

  /// The decoded JSON, or `null` when [stored] is not JSON.
  static Object? _tryDecodeJson(String stored) {
    try {
      return jsonDecode(stored);
    } on FormatException {
      return null;
    }
  }

  static NotificationKind? _kindNamed(String name) {
    for (final kind in NotificationKind.values) {
      if (kind.name == name) return kind;
    }
    return null;
  }
}

final class ItemRemindersDefault extends ItemReminderSetting {
  const ItemRemindersDefault();

  @override
  bool operator ==(Object other) => other is ItemRemindersDefault;

  @override
  int get hashCode => (ItemRemindersDefault).hashCode;
}

final class ItemRemindersMuted extends ItemReminderSetting {
  const ItemRemindersMuted();

  @override
  bool operator ==(Object other) => other is ItemRemindersMuted;

  @override
  int get hashCode => (ItemRemindersMuted).hashCode;
}

final class ItemRemindersCustom extends ItemReminderSetting {
  const ItemRemindersCustom._(this.leadDays, this.once);

  /// Normalised (unique, furthest first) lead times per deadline kind.
  final Map<NotificationKind, List<int>> leadDays;

  /// A one-off reminder, from design-v1's `reminder_at`.
  final OnceReminder? once;

  @override
  bool operator ==(Object other) {
    if (other is! ItemRemindersCustom || other.once != once) return false;
    if (other.leadDays.length != leadDays.length) return false;
    for (final MapEntry(:key, :value) in leadDays.entries) {
      final theirs = other.leadDays[key];
      if (theirs == null || !listEquals(theirs, value)) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    once,
    Object.hashAll([
      for (final kind in NotificationKind.deadlines)
        if (leadDays[kind] case final lead?) Object.hash(kind, Object.hashAll(lead)),
    ]),
  );
}

/// A reminder at one local date and time (floating, like every reminder).
@immutable
final class OnceReminder {
  OnceReminder(DateTime date, this.time) : date = civilDate(date);

  /// Parses `yyyy-MM-ddTHH:mm`; `null` when malformed.
  static OnceReminder? parse(String value) {
    final match = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}:\d{2})$',
    ).firstMatch(value);
    if (match == null) return null;
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final date = DateTime.utc(year, month, day);
    if (date.month != month || date.day != day) return null;
    final time = ReminderTime.parse(match.group(4)!).valueOrNull;
    return time == null ? null : OnceReminder(date, time);
  }

  /// Civil date (UTC midnight).
  final DateTime date;
  final ReminderTime time;

  String get stored =>
      '${date.toIso8601String().substring(0, 10)}T${time.stored}';

  @override
  bool operator ==(Object other) =>
      other is OnceReminder && other.date == date && other.time == time;

  @override
  int get hashCode => Object.hash(date, time);
}
