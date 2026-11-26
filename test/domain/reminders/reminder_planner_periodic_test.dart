import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrawer/core/failure/app_failure.dart';
import 'package:paperdrawer/domain/plans/plan_policy.dart';
import 'package:paperdrawer/domain/reminders/item_reminder_setting.dart';
import 'package:paperdrawer/domain/reminders/notification_actions.dart';
import 'package:paperdrawer/domain/reminders/notification_kind.dart';
import 'package:paperdrawer/domain/reminders/notification_preferences.dart';
import 'package:paperdrawer/domain/reminders/notification_subject.dart';
import 'package:paperdrawer/domain/reminders/planned_notification.dart';
import 'package:paperdrawer/domain/reminders/reminder_planner.dart';

import 'reminder_fixtures.dart';

void main() {
  const returns = NotificationKind.returnWindow;
  const policyKind = NotificationKind.policyRenewal;
  const weekly = NotificationKind.weeklySummary;
  const unfinished = NotificationKind.unfinishedItem;
  const backup = NotificationKind.backupReminder;

  List<PlannedNotification> ofKind(ReminderPlan plan, NotificationKind kind) =>
      plan.notifications.where((n) => n.kind == kind).toList();

  ReminderPlan planAt(ReminderPlanInput planInput, List<int> at) =>
      ReminderPlanner(
        clockAt(at[0], at[1], at[2], at.length > 3 ? at[3] : 8),
      ).plan(planInput);

  group('weekly summary', () {
    final items = [
      item('a', [deadline(returns, day(2026, 11, 30))], name: 'Earbuds'),
      item('b', [
        deadline(policyKind, day(2026, 12, 6), renews: true),
      ], name: 'Family health policy'),
      item('c', [deadline(returns, day(2026, 12, 7))], name: 'Kettle'),
    ];

    test('fires on Mondays at the time of day with what is due that week', () {
      final plan = planAt(input(items), [2026, 11, 25]);
      final summaries = ofKind(plan, weekly);
      expect(summaries.map((n) => (n.fireOn, n.time.stored)), [
        (day(2026, 11, 30), '09:00'),
        (day(2026, 12, 7), '09:00'),
      ]);
      expect(summaries.every((n) => n.fireOn.weekday == DateTime.monday),
          isTrue);
      expect(summaries.first.text.title, 'This week in your drawer');
      expect(summaries.first.text.body,
          '2 things due: Earbuds return and Family health policy renewal.');
      expect(summaries.last.text.body, '1 thing due: Kettle return.');
      expect(summaries.first.payload.route, '/home');
      expect(summaries.first.category, NotificationCategory.general);
      expect(summaries.first.priority, NotificationPriority.other);
    });

    test('uses the chosen time of day', () {
      final prefs =
          NotificationPreferences.defaults().withTimeOfDay(7, 45).requireValue;
      final plan = planAt(input(items, preferences: prefs), [2026, 11, 25]);
      expect(ofKind(plan, weekly).first.time.stored, '07:45');
    });

    test('on a Monday before the time of day, this Monday is included', () {
      final plan = planAt(input(items), [2026, 11, 30, 8]);
      expect(ofKind(plan, weekly).first.fireOn, day(2026, 11, 30));
    });

    test('on a Monday after the time of day, this Monday is skipped', () {
      final plan = planAt(input(items), [2026, 11, 30, 10]);
      expect(ofKind(plan, weekly).first.fireOn, day(2026, 12, 7));
    });

    test('a week with nothing due gets no summary', () {
      final plan = planAt(
        input([item('far', [deadline(returns, day(2027, 6, 1))])]),
        [2026, 11, 25],
      );
      expect(ofKind(plan, weekly), isEmpty);
    });

    test('muted items, done windows and kinds that are off are left out', () {
      final plan = planAt(
        input([
          item('m', [deadline(returns, day(2026, 12, 1))],
              setting: ItemReminderSetting.muted),
          item('d', [deadline(returns, day(2026, 12, 1), done: true)]),
          item('t', [
            deadline(NotificationKind.agreementTerm, day(2026, 12, 1)),
          ]),
        ]),
        [2026, 11, 25],
      );
      expect(ofKind(plan, weekly), isEmpty);
    });

    test('more than three items name two and count the rest', () {
      final plan = planAt(
        input([
          for (final (i, name) in ['A', 'B', 'C', 'D'].indexed)
            item('i$i', [deadline(returns, day(2026, 12, 1 + i))], name: name),
        ]),
        [2026, 11, 25],
      );
      expect(ofKind(plan, weekly).first.text.body,
          '4 things due: A return, B return and 2 more.');
    });

    test('is off when switched off', () {
      final prefs = NotificationPreferences.defaults()
          .withKind(weekly, on: false)
          .requireValue;
      final plan = planAt(input(items, preferences: prefs), [2026, 11, 25]);
      expect(ofKind(plan, weekly), isEmpty);
    });
  });

  group('unfinished items', () {
    test('one day after saving, at the time of day', () {
      final plan = planAt(
        input([
          item('u', const [], name: 'Mixer', savedOn: day(2026, 11, 25),
              isUnfinished: true),
        ]),
        [2026, 11, 25, 15],
      );
      final n = ofKind(plan, unfinished).single;
      expect((n.fireOn, n.time.stored), (day(2026, 11, 26), '09:00'));
      expect(n.text.title, 'Finish adding Mixer');
      expect(n.payload.route, '/vault/item/u');
      expect(n.category, NotificationCategory.item);
    });

    test('not once the day after saving has passed', () {
      final plan = planAt(
        input([
          item('u', const [], savedOn: day(2026, 11, 23), isUnfinished: true),
        ]),
        [2026, 11, 25],
      );
      expect(ofKind(plan, unfinished), isEmpty);
    });

    test('not for finished or muted items', () {
      final plan = planAt(
        input([
          item('f', const [], savedOn: day(2026, 11, 25)),
          item('m', const [], savedOn: day(2026, 11, 25), isUnfinished: true,
              setting: ItemReminderSetting.muted),
        ]),
        [2026, 11, 25],
      );
      expect(ofKind(plan, unfinished), isEmpty);
    });
  });

  group('Base backup reminder', () {
    final drawer = [item('x', const [])];

    test('60 days after the last export, then every 30 days', () {
      final plan = planAt(
        input(drawer, policy: const BasePolicy(),
            lastExportOn: day(2026, 9, 26)),
        [2026, 11, 25],
      );
      final reminders = ofKind(plan, backup);
      expect(reminders.map((n) => n.fireOn), [
        day(2026, 11, 25),
        day(2026, 12, 25),
        day(2027, 1, 24),
      ]);
      expect(
        reminders.map((n) => (n.subject as BackupSubject).daysSinceExport),
        [60, 90, 120],
      );
      expect(reminders.first.text.body,
          'It’s been 60 days since your last export. Base keeps your drawer '
          'on this iPhone only, so save a copy to Files.');
      expect(reminders.first.payload.route, '/settings/data');
    });

    test('a reminder already past today moves to the next 30-day step', () {
      final plan = planAt(
        input(drawer, policy: const BasePolicy(),
            lastExportOn: day(2026, 9, 26)),
        [2026, 11, 25, 10],
      );
      expect(ofKind(plan, backup).map((n) => n.fireOn), [
        day(2026, 12, 25),
        day(2027, 1, 24),
        day(2027, 2, 23),
      ]);
    });

    test('counts from first use when the drawer was never exported', () {
      final plan = planAt(
        input(drawer, policy: const BasePolicy(),
            drawerStartedOn: day(2026, 9, 26)),
        [2026, 11, 25],
      );
      final first = ofKind(plan, backup).first;
      expect(first.fireOn, day(2026, 11, 25));
      expect((first.subject as BackupSubject).daysSinceExport, isNull);
      expect(first.text.body, startsWith('You haven’t exported your drawer'));
    });

    test('a long-overdue export keeps the 30-day rhythm', () {
      final plan = planAt(
        input(drawer, policy: const BasePolicy(),
            lastExportOn: day(2025, 1, 1)),
        [2026, 11, 25],
      );
      final reminders = ofKind(plan, backup);
      expect(reminders.map((n) => n.fireOn), [
        day(2026, 12, 22),
        day(2027, 1, 21),
        day(2027, 2, 20),
      ]);
      expect(
        reminders.map((n) => (n.subject as BackupSubject).daysSinceExport),
        [720, 750, 780],
      );
    });

    test('nothing for an empty drawer or without a start date', () {
      expect(
        ofKind(
          planAt(input(const [], policy: const BasePolicy(),
              drawerStartedOn: day(2026, 1, 1)), [2026, 11, 25]),
          backup,
        ),
        isEmpty,
      );
      expect(
        ofKind(planAt(input(drawer, policy: const BasePolicy()),
            [2026, 11, 25]), backup),
        isEmpty,
      );
    });
  });

  group('the plan decides which kinds exist', () {
    test('Essential and Pro have no backup reminder', () {
      for (final policy in [const EssentialPolicy(), const ProPolicy()]) {
        final plan = planAt(
          input([item('x', const [])], policy: policy,
              lastExportOn: day(2026, 1, 1)),
          [2026, 11, 25],
        );
        expect(ofKind(plan, backup), isEmpty, reason: '${policy.plan}');
      }
    });

    test('Base has no sync problem notifications', () {
      final planner = ReminderPlanner(clockAt(2026, 11, 25));
      const subject = SyncProblemSubject(SyncPauseReason.iCloudFull);
      expect(
        planner.syncProblem(subject,
            scope: user(),
            policy: const BasePolicy(),
            preferences: NotificationPreferences.defaults()),
        isNull,
      );
      final essential = planner.syncProblem(subject,
          scope: user(),
          policy: const EssentialPolicy(),
          preferences: NotificationPreferences.defaults());
      expect(essential?.text.title, 'iCloud is full');
      expect(essential?.fireOn, day(2026, 11, 25));
      expect(essential?.payload.route, '/settings/account');
      expect(essential!.platformId, greaterThan(0));
    });

    test('going offline never notifies', () {
      final planner = ReminderPlanner(clockAt(2026, 11, 25));
      expect(
        planner.syncProblem(
          const SyncProblemSubject(SyncPauseReason.offline),
          scope: user(),
          policy: const ProPolicy(),
          preferences: NotificationPreferences.defaults(),
        ),
        isNull,
      );
    });

    test('a kind with "This iPhone" off is not scheduled locally', () {
      final prefs = NotificationPreferences.defaults()
          .withKind(returns, push: false)
          .requireValue;
      final plan = planAt(
        input([item('r', [deadline(returns, day(2026, 12, 10))])],
            policy: const ProPolicy(), preferences: prefs),
        [2026, 11, 25],
      );
      expect(plan.notifications.where((n) => n.kind == returns), isEmpty);
      expect(prefs.channelsFor(returns, const ProPolicy()),
          {NotificationChannel.email});
    });
  });
}
