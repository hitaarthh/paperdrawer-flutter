import 'package:flutter/foundation.dart';

import 'notification_actions.dart';
import 'notification_copy.dart';
import 'notification_id.dart';
import 'notification_kind.dart';
import 'notification_payload.dart';
import 'notification_subject.dart';
import 'reminder_item.dart';
import 'reminder_time.dart';

/// Which notifications keep their slot when iOS's 64 limit is full.
enum NotificationPriority {
  /// Deadline reminders, snoozes and one-off item reminders: always first,
  /// nearest first.
  deadline,

  /// Weekly summary, unfinished items, backup: only what is left over.
  other,
}

/// Which reminder of a day this is, for the key.
enum NotificationSlot {
  lead('lead'),
  lastDayRepeat('repeat'),
  snoozed('snooze'),
  once('once'),
  weekly('weekly'),
  unfinished('unfinished'),
  backup('backup'),
  syncProblem('sync');

  const NotificationSlot(this.code);

  final String code;
}

/// One local notification the data layer should schedule.
///
/// It fires on [fireOn] at [time] *local wall-clock time* (floating: it
/// follows the user across time zones). Schedule it with
/// `TZDateTime(tz.local, fireOn.year, fireOn.month, fireOn.day, time.hour,
/// time.minute)` or a calendar trigger.
@immutable
final class PlannedNotification {
  PlannedNotification({
    required this.subject,
    required this.payload,
    required DateTime fireOn,
    required this.time,
    required this.slot,
    required this.text,
    this.timeSensitive = false,
    this.platformId = 0,
  }) : fireOn = DateTime.utc(fireOn.year, fireOn.month, fireOn.day),
       key = keyFor(
         scopeKey: NotificationPayload.scopeKey(payload.scope),
         kind: subject.kind,
         itemId: payload.itemId,
         fireOn: fireOn,
         slot: slot,
         extra: subject is SyncProblemSubject ? subject.reason.name : null,
       );

  /// `<scope>|<kind or once>|<item or ->|<yyyy-mm-dd>|<slot>[|<extra>]`.
  ///
  /// The stable identity of a reminder: same account, kind, item, day and
  /// slot always give the same key and IDs.
  static String keyFor({
    required String scopeKey,
    required NotificationKind? kind,
    required String? itemId,
    required DateTime fireOn,
    required NotificationSlot slot,
    String? extra,
  }) => [
    scopeKey,
    kind?.name ?? 'once',
    itemId ?? '-',
    isoDay(DateTime.utc(fireOn.year, fireOn.month, fireOn.day)),
    slot.code,
    if (extra != null) extra,
  ].join('|');

  final NotificationSubject subject;
  final NotificationPayload payload;
  final DateTime fireOn;
  final ReminderTime time;
  final NotificationSlot slot;
  final NotificationText text;

  /// iOS Time Sensitive interruption level (last-day reminders).
  final bool timeSensitive;

  final String key;

  /// 32-bit-safe ID for `flutter_local_notifications`, unique within its
  /// plan (assigned by the planner; 0 until then).
  final int platformId;

  /// 53-bit stable hash of [key] (`NotificationId.stableId`).
  int get stableId => NotificationId.stableId(key);

  NotificationKind? get kind => subject.kind;

  NotificationPriority get priority => switch (subject) {
    DeadlineSubject() || OnceItemSubject() => NotificationPriority.deadline,
    WeeklySummarySubject() ||
    UnfinishedItemSubject() ||
    BackupSubject() ||
    SyncProblemSubject() ||
    TipSubject() => NotificationPriority.other,
  };

  NotificationCategory get category => switch (subject) {
    DeadlineSubject() => NotificationCategory.deadline,
    OnceItemSubject() || UnfinishedItemSubject() => NotificationCategory.item,
    WeeklySummarySubject() ||
    BackupSubject() ||
    SyncProblemSubject() ||
    TipSubject() => NotificationCategory.general,
  };

  /// [fireOn] at [time] as a floating UTC-tagged value, for ordering and
  /// comparing with `wallClockOf(clock.now())`.
  DateTime get wallClock => time.on(fireOn);

  String get encodedPayload => payload.encode();

  PlannedNotification withPlatformId(int id) => PlannedNotification(
    subject: subject,
    payload: payload,
    fireOn: fireOn,
    time: time,
    slot: slot,
    text: text,
    timeSensitive: timeSensitive,
    platformId: id,
  );

  @override
  bool operator ==(Object other) =>
      other is PlannedNotification &&
      other.key == key &&
      other.text == text &&
      other.time == time &&
      other.payload == payload &&
      other.timeSensitive == timeSensitive &&
      other.platformId == platformId;

  @override
  int get hashCode =>
      Object.hash(key, text, time, payload, timeSensitive, platformId);

  /// Keys and times only: never the copy, which holds item names.
  @override
  String toString() => 'PlannedNotification($key @ ${time.stored})';
}

/// The planner's answer.
@immutable
final class ReminderPlan {
  ReminderPlan({
    required List<PlannedNotification> notifications,
    required this.droppedCount,
    required this.nextDeadline,
  }) : notifications = List.unmodifiable(notifications);

  /// What to schedule, in firing order (then by key). At most the planner's
  /// capacity.
  final List<PlannedNotification> notifications;

  /// Candidates left out because the cap was full.
  final int droppedCount;

  /// The nearest deadline the user wants reminders for, even if its
  /// reminders have already fired (for "You’ll miss the earbuds return on
  /// Fri" when iOS notifications are off). `null` when there is none.
  final DueEntry? nextDeadline;

  /// The next notification to fire ("NEXT REMINDER · FRI 9:00 AM").
  PlannedNotification? get next =>
      notifications.isEmpty ? null : notifications.first;

  /// "14 reminders are scheduled on this iPhone".
  int get scheduledCount => notifications.length;
}
