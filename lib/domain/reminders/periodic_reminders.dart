import '../../core/failure/app_failure.dart';
import 'notification_copy.dart';
import 'notification_kind.dart';
import 'notification_payload.dart';
import 'notification_subject.dart';
import 'planned_notification.dart';
import 'reminder_item.dart';
import 'reminder_planner.dart';
import 'reminder_time.dart';

/// What the rule helpers need from one planning run (see `ReminderPlanner`).
abstract interface class PlanningRun {
  ReminderPlanInput get input;

  /// "Now" as a floating wall-clock value (`wallClockOf`).
  DateTime get now;

  /// Today's civil date.
  DateTime get today;
  CopyDetail get detail;

  /// The lead times [item] uses for [kind] on this iPhone (empty: none).
  List<int> localLeadDays(ReminderItem item, NotificationKind kind);

  /// Whether [day] at [time] is still ahead of [now].
  bool isFuture(DateTime day, ReminderTime time);

  /// Wanted, not-done deadlines of unmuted items between [from] and [to].
  List<DueEntry> dueBetween(DateTime from, DateTime? to);

  PlannedNotification build({
    required NotificationSubject subject,
    required String route,
    required DateTime fireOn,
    required ReminderTime time,
    required NotificationSlot slot,
    String? itemId,
    DateTime? deadline,
    bool timeSensitive = false,
  });
}

/// The kinds that are not about one deadline: weekly summary, unfinished
/// items and the Base backup reminder.
abstract final class PeriodicReminders {
  /// Mondays planned ahead. Local notifications carry fixed text, so the
  /// summary is re-planned whenever the app opens or an item changes.
  static const weeklySummaryWeeks = 4;

  /// Days without an export before the first backup reminder.
  static const backupFirstAfterDays = 60;

  /// Days between later backup reminders.
  static const backupRepeatDays = 30;

  /// Backup reminders planned ahead.
  static const backupPlannedAhead = 3;

  /// Whether a sync pause is worth a notification. Offline resolves by
  /// itself, so it never notifies.
  static bool notifiesSyncProblem(SyncPauseReason reason) => switch (reason) {
    SyncPauseReason.iCloudUnavailable ||
    SyncPauseReason.iCloudFull ||
    SyncPauseReason.iCloudAccountMismatch ||
    SyncPauseReason.signInRequired ||
    SyncPauseReason.appUpdateRequired => true,
    SyncPauseReason.offline => false,
  };

  /// Monday mornings at the time of day: what's due Monday to Sunday.
  /// Weeks with nothing due get no summary.
  static List<PlannedNotification> weekly(PlanningRun run) {
    final input = run.input;
    if (!input.preferences.pushes(NotificationKind.weeklySummary, input.policy)) {
      return const [];
    }
    final time = input.preferences.timeOfDay;
    final today = run.today;
    final firstMonday = _addDays(today, (DateTime.monday - today.weekday) % 7);
    final out = <PlannedNotification>[];
    for (var week = 0; week < weeklySummaryWeeks; week++) {
      final monday = _addDays(firstMonday, week * 7);
      if (!run.isFuture(monday, time)) continue;
      final entries = run.dueBetween(monday, _addDays(monday, 6));
      if (entries.isEmpty) continue;
      out.add(
        run.build(
          subject: WeeklySummarySubject(weekStart: monday, entries: entries),
          route: NotificationRoutes.home,
          fireOn: monday,
          time: time,
          slot: NotificationSlot.weekly,
        ),
      );
    }
    return out;
  }

  /// One day after saving, at the time of day, for items saved without an
  /// end date or a photo. Muted items are skipped.
  static List<PlannedNotification> unfinished(PlanningRun run) {
    final input = run.input;
    if (!input.preferences.pushes(NotificationKind.unfinishedItem, input.policy)) {
      return const [];
    }
    final time = input.preferences.timeOfDay;
    return [
      for (final item in input.items)
        if (item.isUnfinished && !item.setting.isMuted)
          if (item.savedOn case final savedOn?)
            if (run.isFuture(_addDays(savedOn, 1), time))
              run.build(
                subject: UnfinishedItemSubject(
                  itemId: item.id,
                  itemName: item.name,
                ),
                route: NotificationRoutes.item(item.id),
                fireOn: _addDays(savedOn, 1),
                time: time,
                slot: NotificationSlot.unfinished,
                itemId: item.id,
              ),
    ];
  }

  /// Base only (the plan decides): 60 days after the last export, or after
  /// the drawer was first used when it was never exported, then every 30
  /// days. Nothing for an empty drawer.
  static List<PlannedNotification> backup(PlanningRun run) {
    final input = run.input;
    if (!input.preferences.pushes(NotificationKind.backupReminder, input.policy)) {
      return const [];
    }
    final baseline = input.lastExportOn ?? input.drawerStartedOn;
    if (baseline == null || input.items.isEmpty) return const [];
    final time = input.preferences.timeOfDay;
    final today = run.today;
    final first = _addDays(baseline, backupFirstAfterDays);
    // Skip occurrences before today without looping through them.
    final behind = today.difference(_civil(first)).inDays;
    var index = behind <= 0 ? 0 : behind ~/ backupRepeatDays;
    final out = <PlannedNotification>[];
    while (out.length < backupPlannedAhead) {
      final fireOn = _addDays(first, index * backupRepeatDays);
      index++;
      if (fireOn.isBefore(today) || !run.isFuture(fireOn, time)) continue;
      out.add(
        run.build(
          subject: BackupSubject(
            daysSinceExport: input.lastExportOn == null
                ? null
                : fireOn.difference(_civil(baseline)).inDays,
          ),
          route: NotificationRoutes.yourData,
          fireOn: fireOn,
          time: time,
          slot: NotificationSlot.backup,
        ),
      );
    }
    return out;
  }

  static DateTime _civil(DateTime day) =>
      DateTime.utc(day.year, day.month, day.day);

  static DateTime _addDays(DateTime day, int days) =>
      DateTime.utc(day.year, day.month, day.day + days);
}
