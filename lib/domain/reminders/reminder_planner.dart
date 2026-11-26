import 'package:flutter/foundation.dart';

import '../../core/time/clock.dart';
import '../account/account_scope.dart';
import '../plans/plan_policy.dart';
import 'item_reminder_setting.dart';
import 'notification_copy.dart';
import 'notification_id.dart';
import 'notification_kind.dart';
import 'notification_payload.dart';
import 'notification_preferences.dart';
import 'notification_subject.dart';
import 'periodic_reminders.dart';
import 'planned_notification.dart';
import 'reminder_item.dart';
import 'reminder_time.dart';

/// Everything one planning run looks at, for one account's drawer.
@immutable
final class ReminderPlanInput {
  ReminderPlanInput({
    required this.scope,
    required this.policy,
    required this.preferences,
    required List<ReminderItem> items,
    List<ReminderSnooze> snoozes = const [],
    this.lastExportOn,
    this.drawerStartedOn,
    this.forOtherAccount = false,
  }) : items = List.unmodifiable(items),
       snoozes = List.unmodifiable(snoozes);

  /// Whose drawer; written into every payload and key.
  final AccountScope scope;

  /// Decides which kinds exist and which channels they may use.
  final PlanPolicy policy;
  final NotificationPreferences preferences;

  /// Every active (not archived) item.
  final List<ReminderItem> items;
  final List<ReminderSnooze> snoozes;

  /// The local day of the last export, or `null` if never exported.
  final DateTime? lastExportOn;

  /// The local day this drawer was first used (the backup clock starts here
  /// when it was never exported).
  final DateTime? drawerStartedOn;

  /// Plan an account that is *not* the open one, on a shared phone
  /// (`OtherAccountReminders.keepNeutral`): deadlines only, neutral text.
  final bool forOtherAccount;
}

/// Turns items, preferences and the plan into the local notifications to
/// schedule. Pure: time comes from the injected [Clock].
///
/// Rules (spec "Reminders and notifications", boards iOSNotifications*):
/// - Deadline kinds: one reminder per lead time at the time of day, from
///   the item's setting (`ItemReminderSetting.leadDaysFor`); nothing for
///   muted items, windows marked done, or reminders already in the past.
/// - "On the day" reminders are Time Sensitive when that control is on.
/// - Keep reminding on the last day: a second reminder at 6:00 PM when the
///   item reminds on the day, the window is not done, and the time of day is
///   before 6:00 PM.
/// - "Remind me tomorrow" holds back the window's reminders before the
///   snooze day and fires once on that day at the time of day.
/// - Weekly summary on Mondays at the time of day, for the next
///   [PeriodicReminders.weeklySummaryWeeks] weeks, when something is due
///   that week. Unfinished items one day after saving. Base backup 60 days
///   after the last export (or first use), then every 30.
/// - Only kinds the plan offers and the user has on, on the push channel.
/// - At most [capacity] (iOS allows 64 per app): deadline reminders first,
///   nearest first; other kinds fill what is left.
/// - Output is sorted by firing time, then key: the same input always gives
///   the same plan.
final class ReminderPlanner {
  const ReminderPlanner(this._clock, {this.capacity = iosLimit});

  /// iOS's limit on pending local notifications per app.
  static const iosLimit = 64;

  final Clock _clock;
  final int capacity;

  ReminderPlan plan(ReminderPlanInput input) {
    final run = _Run(input, _clock);
    final candidates = <PlannedNotification>[
      for (final item in input.items) ...run.deadlineReminders(item),
      if (!input.forOtherAccount) ...[
        ...PeriodicReminders.weekly(run),
        ...PeriodicReminders.unfinished(run),
        ...PeriodicReminders.backup(run),
      ],
    ];
    return _cap(candidates, run.nextDeadline());
  }

  /// A sync problem to show now, or `null` when the plan doesn't offer the
  /// kind, the user turned it off, or the reason resolves by itself
  /// (offline).
  PlannedNotification? syncProblem(
    SyncProblemSubject subject, {
    required AccountScope scope,
    required PlanPolicy policy,
    required NotificationPreferences preferences,
  }) {
    if (!preferences.pushes(NotificationKind.syncProblem, policy)) return null;
    if (!PeriodicReminders.notifiesSyncProblem(subject.reason)) return null;
    final now = _clock.now();
    final planned = PlannedNotification(
      subject: subject,
      payload: NotificationPayload(
        scope: scope,
        route: NotificationRoutes.account,
        kind: NotificationKind.syncProblem,
      ),
      fireOn: _clock.today(),
      time: ReminderTime.ofInstant(now),
      slot: NotificationSlot.syncProblem,
      text: NotificationCopy.text(subject, CopyDetail.full),
    );
    return planned.withPlatformId(NotificationId.platformId(planned.stableId));
  }

  ReminderPlan _cap(
    List<PlannedNotification> candidates,
    DueEntry? nextDeadline,
  ) {
    final byPriority = [...candidates]
      ..sort((a, b) {
        final priority = a.priority.index - b.priority.index;
        return priority != 0 ? priority : _chronological(a, b);
      });
    final kept = byPriority.take(capacity < 0 ? 0 : capacity).toList()
      ..sort(_chronological);
    return ReminderPlan(
      notifications: _assignPlatformIds(kept),
      droppedCount: byPriority.length - kept.length,
      nextDeadline: nextDeadline,
    );
  }

  static int _chronological(PlannedNotification a, PlannedNotification b) {
    final time = a.wallClock.compareTo(b.wallClock);
    return time != 0 ? time : a.key.compareTo(b.key);
  }

  /// Folds each stable ID into the plugin's 32-bit range. On the rare
  /// collision the later notification (in plan order) takes the next free
  /// ID, so the result is still deterministic for the same plan.
  static List<PlannedNotification> _assignPlatformIds(
    List<PlannedNotification> notifications,
  ) {
    final used = <int>{};
    return [
      for (final n in notifications)
        n.withPlatformId(_freeId(NotificationId.platformId(n.stableId), used)),
    ];
  }

  static int _freeId(int wanted, Set<int> used) {
    var id = wanted;
    while (!used.add(id)) {
      id = id == NotificationId.maxPlatformId ? 1 : id + 1;
    }
    return id;
  }
}

/// One planning run: the input plus "now", shared by the rule helpers.
final class _Run implements PlanningRun {
  _Run(this.input, Clock clock)
    : now = wallClockOf(clock.now()),
      today = clock.today(),
      detail = input.forOtherAccount
          ? CopyDetail.otherAccount
          : switch (input.preferences.lockScreen) {
              LockScreenDetail.showNames => CopyDetail.full,
              LockScreenDetail.hideDetails => CopyDetail.hidden,
            };

  @override
  final ReminderPlanInput input;
  @override
  final DateTime now;
  @override
  final DateTime today;
  @override
  final CopyDetail detail;

  NotificationPreferences get _prefs => input.preferences;

  /// The lead times [item] uses for [kind] on the push channel; empty when
  /// the plan doesn't offer the kind or "This iPhone" is off for it.
  @override
  List<int> localLeadDays(ReminderItem item, NotificationKind kind) {
    if (!_pushAllowed(kind)) return const [];
    return item.setting.leadDaysFor(kind, _prefs);
  }

  @override
  bool isFuture(DateTime day, ReminderTime time) => time.on(day).isAfter(now);

  @override
  PlannedNotification build({
    required NotificationSubject subject,
    required String route,
    required DateTime fireOn,
    required ReminderTime time,
    required NotificationSlot slot,
    String? itemId,
    DateTime? deadline,
    bool timeSensitive = false,
  }) => PlannedNotification(
    subject: subject,
    payload: NotificationPayload(
      scope: input.scope,
      route: route,
      kind: subject.kind,
      itemId: itemId,
      deadline: deadline,
    ),
    fireOn: fireOn,
    time: time,
    slot: slot,
    text: NotificationCopy.text(subject, detail),
    timeSensitive: timeSensitive,
  );

  List<PlannedNotification> deadlineReminders(ReminderItem item) {
    if (item.setting.isMuted) return const [];
    return [
      for (final deadline in item.deadlines)
        if (!deadline.done) ..._windowReminders(item, deadline),
      ?_once(item),
    ];
  }

  List<PlannedNotification> _windowReminders(
    ReminderItem item,
    ReminderDeadline deadline,
  ) {
    final leads = localLeadDays(item, deadline.kind);
    final snooze = _snoozeFor(item, deadline);
    final holdUntil = snooze?.until;
    final out = <PlannedNotification>[];

    void add(DateTime fireOn, ReminderTime time, DeadlineMoment moment) {
      if (fireOn.isBefore(today) || !isFuture(fireOn, time)) return;
      if (moment != DeadlineMoment.snoozed &&
          holdUntil != null &&
          fireOn.isBefore(holdUntil)) {
        return;
      }
      final subject = DeadlineSubject(
        itemId: item.id,
        itemName: item.name,
        deadline: deadline,
        fireOn: fireOn,
        moment: moment,
      );
      out.add(
        build(
          subject: subject,
          route: NotificationRoutes.item(item.id),
          fireOn: fireOn,
          time: time,
          slot: switch (moment) {
            DeadlineMoment.lead => NotificationSlot.lead,
            DeadlineMoment.lastDayRepeat => NotificationSlot.lastDayRepeat,
            DeadlineMoment.snoozed => NotificationSlot.snoozed,
          },
          itemId: item.id,
          deadline: deadline.date,
          timeSensitive: subject.isLastDay && _prefs.timeSensitiveLastDay,
        ),
      );
    }

    final time = _prefs.timeOfDay;
    for (final days in leads) {
      add(_addDays(deadline.date, -days), time, DeadlineMoment.lead);
    }
    const repeatAt = NotificationPreferences.lastDayRepeatTime;
    if (_prefs.lastDayRepeat &&
        leads.contains(0) &&
        time.isBefore(repeatAt)) {
      add(deadline.date, repeatAt, DeadlineMoment.lastDayRepeat);
    }
    // A snooze fires even if the user has since removed every lead time
    // (they asked for it explicitly), as long as the kind may still use this
    // iPhone. It is skipped when a lead reminder fires at the same moment.
    if (snooze != null &&
        _pushAllowed(deadline.kind) &&
        !out.any((n) => n.fireOn == snooze.until && n.time == time)) {
      add(snooze.until, time, DeadlineMoment.snoozed);
    }
    return out;
  }

  bool _pushAllowed(NotificationKind kind) =>
      input.policy.channelsFor(kind).contains(NotificationChannel.push) &&
      _prefs[kind].push;

  /// The latest still-current snooze for [deadline], if any.
  ReminderSnooze? _snoozeFor(ReminderItem item, ReminderDeadline deadline) {
    ReminderSnooze? found;
    for (final snooze in input.snoozes) {
      if (!snooze.appliesTo(item.id, deadline) || snooze.isExpired(today)) {
        continue;
      }
      if (found == null || snooze.until.isAfter(found.until)) found = snooze;
    }
    return found;
  }

  PlannedNotification? _once(ReminderItem item) {
    final once = switch (item.setting) {
      ItemRemindersCustom(:final once) => once,
      ItemRemindersDefault() || ItemRemindersMuted() => null,
    };
    if (once == null || !isFuture(once.date, once.time)) return null;
    return build(
      subject: OnceItemSubject(itemId: item.id, itemName: item.name),
      route: NotificationRoutes.item(item.id),
      fireOn: once.date,
      time: once.time,
      slot: NotificationSlot.once,
      itemId: item.id,
    );
  }

  /// The nearest wanted deadline from today on (see
  /// `ReminderPlan.nextDeadline`).
  DueEntry? nextDeadline() {
    final due = dueBetween(today, null);
    return due.isEmpty ? null : due.first;
  }

  /// Wanted, not-done deadlines of unmuted items with [from] ≤ date ≤ [to]
  /// (no upper bound when [to] is null), nearest first, then by name, kind
  /// and item ID.
  @override
  List<DueEntry> dueBetween(DateTime from, DateTime? to) {
    final entries = <DueEntry>[
      for (final item in input.items)
        if (!item.setting.isMuted)
          for (final d in item.deadlines)
            if (!d.done &&
                !d.date.isBefore(from) &&
                (to == null || !d.date.isAfter(to)) &&
                localLeadDays(item, d.kind).isNotEmpty)
              DueEntry(itemId: item.id, itemName: item.name, deadline: d),
    ];
    entries.sort((a, b) {
      var c = a.deadline.date.compareTo(b.deadline.date);
      if (c == 0) c = a.itemName.compareTo(b.itemName);
      if (c == 0) c = a.deadline.kind.index - b.deadline.kind.index;
      if (c == 0) c = a.itemId.compareTo(b.itemId);
      return c;
    });
    return entries;
  }
}

DateTime _addDays(DateTime day, int days) =>
    DateTime.utc(day.year, day.month, day.day + days);
