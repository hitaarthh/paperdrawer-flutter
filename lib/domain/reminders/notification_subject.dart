import 'package:flutter/foundation.dart';

import '../../core/failure/app_failure.dart';
import '../../core/time/clock.dart';
import 'notification_kind.dart';
import 'reminder_item.dart';

/// What one notification is about: the facts its copy is written from.
///
/// Closed set: `NotificationCopy.text` switches over it exhaustively.
@immutable
sealed class NotificationSubject {
  const NotificationSubject();

  /// The kind, or `null` for a one-off item reminder (design-v1's
  /// `reminder_at`), which belongs to no kind.
  NotificationKind? get kind;
}

/// Which reminder of a deadline this is.
enum DeadlineMoment {
  /// A lead-time reminder at the time of day (including "on the day").
  lead,

  /// The second last-day reminder at 6:00 PM.
  lastDayRepeat,

  /// "Remind me tomorrow", fired.
  snoozed,
}

/// A deadline reminder for one window of one item.
final class DeadlineSubject extends NotificationSubject {
  DeadlineSubject({
    required this.itemId,
    required this.itemName,
    required this.deadline,
    required DateTime fireOn,
    this.moment = DeadlineMoment.lead,
  }) : fireOn = civilDate(fireOn);

  final String itemId;
  final String itemName;
  final ReminderDeadline deadline;

  /// The day it fires; the copy counts days from here.
  final DateTime fireOn;
  final DeadlineMoment moment;

  /// 0 on the last day, negative once ended (a snooze past the end).
  int get daysLeft => deadline.daysLeftOn(fireOn);

  bool get isLastDay => daysLeft == 0;

  @override
  NotificationKind get kind => deadline.kind;
}

/// A one-off reminder the user set on an item (design-v1's `reminder_at`).
final class OnceItemSubject extends NotificationSubject {
  const OnceItemSubject({required this.itemId, required this.itemName});

  final String itemId;
  final String itemName;

  @override
  NotificationKind? get kind => null;
}

/// One due deadline of one item: a line of the weekly summary, or the
/// deadline Settings says will be missed when notifications are off.
@immutable
final class DueEntry {
  const DueEntry({
    required this.itemId,
    required this.itemName,
    required this.deadline,
  });

  final String itemId;
  final String itemName;
  final ReminderDeadline deadline;
}

/// Monday morning: what's due this week (Monday to Sunday).
final class WeeklySummarySubject extends NotificationSubject {
  WeeklySummarySubject({
    required DateTime weekStart,
    required List<DueEntry> entries,
  }) : weekStart = civilDate(weekStart),
       entries = List.unmodifiable(entries);

  final DateTime weekStart;

  /// Nearest first.
  final List<DueEntry> entries;

  @override
  NotificationKind get kind => NotificationKind.weeklySummary;
}

/// An item saved without an end date or a photo, one day later.
final class UnfinishedItemSubject extends NotificationSubject {
  const UnfinishedItemSubject({required this.itemId, required this.itemName});

  final String itemId;
  final String itemName;

  @override
  NotificationKind get kind => NotificationKind.unfinishedItem;
}

/// Base: no export in 60 days (then every 30).
final class BackupSubject extends NotificationSubject {
  const BackupSubject({required this.daysSinceExport});

  /// Days since the last export on the day it fires; `null` when the drawer
  /// has never been exported.
  final int? daysSinceExport;

  @override
  NotificationKind get kind => NotificationKind.backupReminder;
}

/// Essential and Pro: sync stopped for a reason the user can act on.
final class SyncProblemSubject extends NotificationSubject {
  const SyncProblemSubject(this.reason);

  final SyncPauseReason reason;

  @override
  NotificationKind get kind => NotificationKind.syncProblem;
}

/// Product news, written elsewhere (at most once a month).
final class TipSubject extends NotificationSubject {
  const TipSubject({required this.title, required this.body});

  final String title;
  final String body;

  @override
  NotificationKind get kind => NotificationKind.tips;
}
