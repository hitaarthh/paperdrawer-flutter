import 'package:flutter/foundation.dart';

import '../../core/time/clock.dart';
import 'item_reminder_setting.dart';
import 'notification_kind.dart';

/// One deadline of an item, as the planner sees it.
///
/// Built from a `CoverWindow` with `deadlineFromWindow` (window_kind.dart).
@immutable
final class ReminderDeadline {
  ReminderDeadline({
    required this.kind,
    required DateTime date,
    this.renews = false,
    this.partName = '',
    this.done = false,
    this.keepsNoClaimBonus = false,
  }) : date = civilDate(date),
       assert(kind.isDeadline, '$kind is not a deadline kind');

  final NotificationKind kind;

  /// The last day of the window (inclusive), as a civil date.
  final DateTime date;

  /// Policies and agreements that renew rather than end.
  final bool renews;

  /// A part warranty's part ("Compressor"); empty otherwise.
  final String partName;

  /// The user marked this window done for this [date]: no reminders, no
  /// last-day repeat, and it leaves the weekly summary.
  final bool done;

  /// Health and motor policies: renewal copy mentions the no-claim bonus.
  final bool keepsNoClaimBonus;

  /// The marker that records "done" for this deadline.
  DeadlineMark get mark => DeadlineMark(kind, date);

  /// Days from [day] to the last day: 0 on the day, negative once ended.
  int daysLeftOn(DateTime day) => date.difference(civilDate(day)).inDays;

  @override
  bool operator ==(Object other) =>
      other is ReminderDeadline &&
      other.kind == kind &&
      other.date == date &&
      other.renews == renews &&
      other.partName == partName &&
      other.done == done &&
      other.keepsNoClaimBonus == keepsNoClaimBonus;

  @override
  int get hashCode =>
      Object.hash(kind, date, renews, partName, done, keepsNoClaimBonus);
}

/// "Mark as done" for one window of one item, tied to its end date.
///
/// Storing the date means a renewed policy (a new end date) is reminded
/// again without anyone clearing the old mark. Stored form: `kind@yyyy-mm-dd`.
@immutable
final class DeadlineMark {
  DeadlineMark(this.kind, DateTime date) : date = civilDate(date);

  /// Parses [stored]; `null` when malformed.
  static DeadlineMark? parse(String stored) {
    final at = stored.indexOf('@');
    if (at <= 0) return null;
    final name = stored.substring(0, at);
    final date = _parseDate(stored.substring(at + 1));
    for (final kind in NotificationKind.deadlines) {
      if (kind.name == name && date != null) return DeadlineMark(kind, date);
    }
    return null;
  }

  final NotificationKind kind;
  final DateTime date;

  String get stored => '${kind.name}@${isoDay(date)}';

  /// Whether this mark covers [deadline] (same kind, same end date).
  bool matches(ReminderDeadline deadline) =>
      deadline.kind == kind && deadline.date == date;

  @override
  bool operator ==(Object other) =>
      other is DeadlineMark && other.kind == kind && other.date == date;

  @override
  int get hashCode => Object.hash(kind, date);
}

/// "Remind me tomorrow" on one deadline.
///
/// Until [until], the window's own reminders are held back (so a snooze on
/// the last morning also skips that evening's 6:00 PM repeat); on [until]
/// one reminder fires at the time of day. Created by
/// `NotificationActionResolver` from the tapped notification's payload.
@immutable
final class ReminderSnooze {
  ReminderSnooze({
    required this.itemId,
    required this.kind,
    required DateTime deadline,
    required DateTime until,
  }) : deadline = civilDate(deadline),
       until = civilDate(until);

  /// "Remind me tomorrow", pressed on [today].
  factory ReminderSnooze.tomorrow({
    required String itemId,
    required NotificationKind kind,
    required DateTime deadline,
    required DateTime today,
  }) => ReminderSnooze(
    itemId: itemId,
    kind: kind,
    deadline: deadline,
    until: DateTime.utc(today.year, today.month, today.day + 1),
  );

  final String itemId;
  final NotificationKind kind;

  /// The deadline's end date when the snooze was made. A changed date makes
  /// the snooze stale (it no longer applies).
  final DateTime deadline;

  /// The day the snoozed reminder fires.
  final DateTime until;

  /// Whether this snooze is about [deadline] of item [itemId].
  bool appliesTo(String itemId, ReminderDeadline deadline) =>
      itemId == this.itemId &&
      deadline.kind == kind &&
      deadline.date == this.deadline;

  /// A snooze whose day has passed can be deleted from storage.
  bool isExpired(DateTime today) => until.isBefore(civilDate(today));

  @override
  bool operator ==(Object other) =>
      other is ReminderSnooze &&
      other.itemId == itemId &&
      other.kind == kind &&
      other.deadline == deadline &&
      other.until == until;

  @override
  int get hashCode => Object.hash(itemId, kind, deadline, until);
}

/// One active (not archived) item, as the planner sees it.
@immutable
final class ReminderItem {
  ReminderItem({
    required this.id,
    required this.name,
    required List<ReminderDeadline> deadlines,
    this.setting = ItemReminderSetting.defaults,
    DateTime? savedOn,
    this.isUnfinished = false,
  }) : deadlines = List.unmodifiable(deadlines),
       savedOn = savedOn == null ? null : civilDate(savedOn);

  final String id;

  /// The item's name. Only ever used for notification copy on this device.
  final String name;
  final List<ReminderDeadline> deadlines;
  final ItemReminderSetting setting;

  /// The local day the item was first saved (for "unfinished items").
  final DateTime? savedOn;

  /// Saved without an end date or without a photo of the bill.
  final bool isUnfinished;
}

/// `yyyy-mm-dd` of a civil date.
String isoDay(DateTime date) => date.toIso8601String().substring(0, 10);

DateTime? _parseDate(String value) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final date = DateTime.utc(year, month, day);
  return date.month == month && date.day == day ? date : null;
}

/// Parses `yyyy-mm-dd` strictly (rejects 2026-02-30); `null` when invalid.
DateTime? parseIsoDay(String value) => _parseDate(value);
