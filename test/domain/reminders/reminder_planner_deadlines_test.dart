import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrawer/domain/reminders/item_reminder_setting.dart';
import 'package:paperdrawer/domain/reminders/notification_actions.dart';
import 'package:paperdrawer/domain/reminders/notification_kind.dart';
import 'package:paperdrawer/domain/reminders/notification_preferences.dart';
import 'package:paperdrawer/domain/reminders/notification_subject.dart';
import 'package:paperdrawer/domain/reminders/planned_notification.dart';
import 'package:paperdrawer/domain/reminders/reminder_item.dart';
import 'package:paperdrawer/domain/reminders/reminder_planner.dart';

import 'reminder_fixtures.dart';

void main() {
  const returns = NotificationKind.returnWindow;
  const warranty = NotificationKind.warranty;
  final returnsOnly = only({returns});

  List<(DateTime, String)> when(ReminderPlan plan) => [
    for (final n in plan.notifications) (n.fireOn, n.time.stored),
  ];

  ReminderPlan planAt(
    ReminderPlanInput planInput, {
    required List<int> at,
    int capacity = ReminderPlanner.iosLimit,
  }) => ReminderPlanner(
    clockAt(at[0], at[1], at[2], at.length > 3 ? at[3] : 8),
    capacity: capacity,
  ).plan(planInput);

  group('lead-time reminders', () {
    test('a return window in two days reminds on the day at 9:00 and 6:00 PM',
        () {
      final plan = planAt(
        input([item('r1', [deadline(returns, day(2026, 11, 27))])],
            preferences: returnsOnly),
        at: [2026, 11, 25],
      );
      // The 3-day reminder (24 Nov) is already past.
      expect(when(plan), [
        (day(2026, 11, 27), '09:00'),
        (day(2026, 11, 27), '18:00'),
      ]);
      expect(plan.notifications.every((n) => n.timeSensitive), isTrue);
      expect(plan.notifications.first.slot, NotificationSlot.lead);
      expect(plan.notifications.last.slot, NotificationSlot.lastDayRepeat);
    });

    test('due today before 9:00 keeps both last-day reminders', () {
      final plan = planAt(
        input([item('r1', [deadline(returns, day(2026, 11, 27))])],
            preferences: returnsOnly),
        at: [2026, 11, 27, 8],
      );
      expect(when(plan), [
        (day(2026, 11, 27), '09:00'),
        (day(2026, 11, 27), '18:00'),
      ]);
    });

    test('due today after 9:00 keeps only the 6:00 PM reminder', () {
      final plan = planAt(
        input([item('r1', [deadline(returns, day(2026, 11, 27))])],
            preferences: returnsOnly),
        at: [2026, 11, 27, 10],
      );
      expect(when(plan), [(day(2026, 11, 27), '18:00')]);
    });

    test('due today after 6:00 PM schedules nothing', () {
      final plan = planAt(
        input([item('r1', [deadline(returns, day(2026, 11, 27))])],
            preferences: returnsOnly),
        at: [2026, 11, 27, 19],
      );
      expect(plan.notifications, isEmpty);
    });

    test('due tomorrow with a 1-day lead reminds today and says tomorrow', () {
      final prefs = withLeads(returns, [1, 0], returnsOnly);
      final plan = planAt(
        input([item('r1', [deadline(returns, day(2026, 11, 27))])],
            preferences: prefs),
        at: [2026, 11, 26],
      );
      expect(when(plan), [
        (day(2026, 11, 26), '09:00'),
        (day(2026, 11, 27), '09:00'),
        (day(2026, 11, 27), '18:00'),
      ]);
      expect(plan.notifications.first.text.title,
          'Return window closes tomorrow');
      expect(plan.notifications.first.timeSensitive, isFalse);
    });

    test('a deadline already past schedules nothing', () {
      final plan = planAt(
        input([item('r1', [deadline(returns, day(2026, 11, 20))])],
            preferences: returnsOnly),
        at: [2026, 11, 25],
      );
      expect(plan.notifications, isEmpty);
      expect(plan.nextDeadline, isNull);
    });

    test('lead times cross a month end', () {
      final prefs = withLeads(warranty, [30, 7, 1], only({warranty}));
      final plan = planAt(
        input([item('w1', [deadline(warranty, day(2026, 12, 1))])],
            preferences: prefs),
        at: [2026, 10, 1],
      );
      expect(when(plan), [
        (day(2026, 11, 1), '09:00'),
        (day(2026, 11, 24), '09:00'),
        (day(2026, 11, 30), '09:00'),
      ]);
    });

    test('lead times land on and count across a leap day', () {
      final prefs = withLeads(warranty, [1, 0], only({warranty}));
      final plan = planAt(
        input([
          item('leap', [deadline(warranty, day(2028, 2, 29))]),
          item('march', [deadline(warranty, day(2028, 3, 1))]),
        ], preferences: prefs),
        at: [2028, 2, 1],
      );
      expect(when(plan), [
        (day(2028, 2, 28), '09:00'),
        (day(2028, 2, 29), '09:00'),
        (day(2028, 2, 29), '09:00'),
        (day(2028, 2, 29), '18:00'),
        (day(2028, 3, 1), '09:00'),
        (day(2028, 3, 1), '18:00'),
      ]);
      final march = plan.notifications.firstWhere(
        (n) => n.payload.itemId == 'march' && n.fireOn == day(2028, 2, 29),
      );
      expect((march.subject as DeadlineSubject).daysLeft, 1);
    });

    test('the chosen time of day is used for every lead reminder', () {
      final prefs = returnsOnly.withTimeOfDay(7, 30).requireValue;
      final plan = planAt(
        input([item('r1', [deadline(returns, day(2026, 12, 10))])],
            preferences: prefs),
        at: [2026, 11, 25],
      );
      expect(when(plan), [
        (day(2026, 12, 7), '07:30'),
        (day(2026, 12, 10), '07:30'),
        (day(2026, 12, 10), '18:00'),
      ]);
    });
  });

  group('last day', () {
    final item27 = item('r1', [deadline(returns, day(2026, 11, 27))]);

    test('no 6:00 PM repeat when it is switched off', () {
      final prefs = returnsOnly.withShared(lastDayRepeat: false);
      final plan = planAt(input([item27], preferences: prefs),
          at: [2026, 11, 25]);
      expect(when(plan), [(day(2026, 11, 27), '09:00')]);
    });

    test('no repeat when the window is marked done', () {
      final done = item('r1', [
        deadline(returns, day(2026, 11, 27), done: true),
      ]);
      final plan = planAt(input([done], preferences: returnsOnly),
          at: [2026, 11, 27, 10]);
      expect(plan.notifications, isEmpty);
    });

    test('no repeat when the item does not remind on the day', () {
      final prefs = withLeads(returns, [1], returnsOnly);
      final plan = planAt(input([item27], preferences: prefs),
          at: [2026, 11, 25]);
      expect(when(plan), [(day(2026, 11, 26), '09:00')]);
    });

    test('no repeat when the time of day is already after 6:00 PM', () {
      final prefs = returnsOnly.withTimeOfDay(19, 0).requireValue;
      final plan = planAt(input([item27], preferences: prefs),
          at: [2026, 11, 25]);
      expect(when(plan), [(day(2026, 11, 27), '19:00')]);
    });

    test('Time Sensitive off leaves last-day reminders at the normal level',
        () {
      final prefs = returnsOnly.withShared(timeSensitiveLastDay: false);
      final plan = planAt(input([item27], preferences: prefs),
          at: [2026, 11, 25]);
      expect(plan.notifications.any((n) => n.timeSensitive), isFalse);
    });

    test('only last-day reminders are Time Sensitive', () {
      final prefs = withLeads(returns, [7, 0], returnsOnly);
      final plan = planAt(
        input([item('r1', [deadline(returns, day(2026, 12, 10))])],
            preferences: prefs),
        at: [2026, 11, 25],
      );
      expect([for (final n in plan.notifications) n.timeSensitive],
          [false, true, true]);
    });
  });

  group('per-item settings', () {
    test('a muted item gets no notifications and no next deadline', () {
      final muted = item('m1', [deadline(returns, day(2026, 11, 27))],
          setting: ItemReminderSetting.muted);
      final plan = planAt(input([muted]), at: [2026, 11, 25]);
      expect(plan.notifications, isEmpty);
      expect(plan.nextDeadline, isNull);
    });

    test('custom lead times replace the defaults for that window only', () {
      final custom = ItemReminderSetting.custom({
        returns: [7, 1],
      }).requireValue;
      final plan = planAt(
        input([
          item('c1', [
            deadline(returns, day(2026, 12, 10)),
            deadline(warranty, day(2026, 12, 30)),
          ], setting: custom),
        ], preferences: only({returns, warranty})),
        at: [2026, 11, 25],
      );
      expect(when(plan), [
        (day(2026, 11, 30), '09:00'), // warranty default 30 days
        (day(2026, 12, 3), '09:00'), // return 7 days
        (day(2026, 12, 9), '09:00'), // return 1 day
        (day(2026, 12, 23), '09:00'), // warranty default 7 days
      ]);
    });

    test('custom lead times work even when the kind is off in Settings', () {
      const term = NotificationKind.agreementTerm;
      expect(NotificationPreferences.defaults()[term].on, isFalse);
      final custom = ItemReminderSetting.custom({
        term: [30],
      }).requireValue;
      final plan = planAt(
        input([
          item('a1', [deadline(term, day(2027, 1, 31))], setting: custom),
          item('a2', [deadline(term, day(2027, 1, 31))]),
        ]),
        at: [2026, 11, 25],
      );
      expect(plan.notifications.map((n) => n.payload.itemId), ['a1']);
      expect(plan.notifications.single.fireOn, day(2027, 1, 1));
    });

    test('an empty custom list silences one window', () {
      final custom = ItemReminderSetting.custom({returns: []}).requireValue;
      final plan = planAt(
        input([
          item('c1', [deadline(returns, day(2026, 11, 27))], setting: custom),
        ], preferences: returnsOnly),
        at: [2026, 11, 25],
      );
      expect(plan.notifications, isEmpty);
    });

    test('design-v1 reminder_at becomes a one-off reminder only', () {
      final legacy = ItemReminderSetting.fromLegacy(
        remind: true,
        reminderAtLocal: DateTime(2026, 12, 2, 20, 15),
      );
      final plan = planAt(
        input([item('o1', [deadline(returns, day(2026, 12, 10))],
            name: 'Desk lamp', setting: legacy)]),
        at: [2026, 11, 25],
      );
      expect(when(plan), [(day(2026, 12, 2), '20:15')]);
      final once = plan.notifications.single;
      expect(once.kind, isNull);
      expect(once.priority, NotificationPriority.deadline);
      expect(once.category, NotificationCategory.item);
      expect(once.text.title, 'Desk lamp');
    });
  });

  group('remind me tomorrow', () {
    test('a snooze on the last morning skips that evening and fires tomorrow',
        () {
      final snooze = ReminderSnooze.tomorrow(
        itemId: 'r1',
        kind: returns,
        deadline: day(2026, 11, 27),
        today: day(2026, 11, 27),
      );
      final plan = planAt(
        input([
          item('r1', [deadline(returns, day(2026, 11, 27))], name: 'Earbuds'),
        ], preferences: returnsOnly, snoozes: [snooze]),
        at: [2026, 11, 27, 9],
      );
      expect(when(plan), [(day(2026, 11, 28), '09:00')]);
      final n = plan.notifications.single;
      expect(n.slot, NotificationSlot.snoozed);
      expect(n.text.title, 'Earbuds: return window ended yesterday');
    });

    test('a snooze between lead times fires once and keeps later reminders',
        () {
      final snooze = ReminderSnooze.tomorrow(
        itemId: 'w1',
        kind: warranty,
        deadline: day(2026, 12, 25),
        today: day(2026, 11, 25),
      );
      final plan = planAt(
        input([item('w1', [deadline(warranty, day(2026, 12, 25))])],
            preferences: only({warranty}), snoozes: [snooze]),
        at: [2026, 11, 25, 10],
      );
      expect(when(plan), [
        (day(2026, 11, 26), '09:00'),
        (day(2026, 12, 18), '09:00'),
      ]);
      expect(plan.notifications.first.text.title,
          'Item w1 warranty ends in 29 days');
    });

    test('a snooze for an old end date no longer applies', () {
      final stale = ReminderSnooze.tomorrow(
        itemId: 'r1',
        kind: returns,
        deadline: day(2026, 11, 20),
        today: day(2026, 11, 26),
      );
      final plan = planAt(
        input([item('r1', [deadline(returns, day(2026, 11, 27))])],
            preferences: returnsOnly, snoozes: [stale]),
        at: [2026, 11, 26],
      );
      expect(when(plan), [
        (day(2026, 11, 27), '09:00'),
        (day(2026, 11, 27), '18:00'),
      ]);
    });

    test('an expired snooze is ignored and reported as expired', () {
      final old = ReminderSnooze(
        itemId: 'r1',
        kind: returns,
        deadline: day(2026, 11, 27),
        until: day(2026, 11, 24),
      );
      expect(old.isExpired(day(2026, 11, 25)), isTrue);
      expect(old.isExpired(day(2026, 11, 24)), isFalse);
      final plan = planAt(
        input([item('r1', [deadline(returns, day(2026, 11, 27))])],
            preferences: returnsOnly, snoozes: [old]),
        at: [2026, 11, 25],
      );
      expect(plan.notifications, hasLength(2));
    });

    test('a snooze on the same moment as a lead reminder is not doubled', () {
      final snooze = ReminderSnooze(
        itemId: 'r1',
        kind: returns,
        deadline: day(2026, 12, 10),
        until: day(2026, 12, 7),
      );
      final plan = planAt(
        input([item('r1', [deadline(returns, day(2026, 12, 10))])],
            preferences: returnsOnly, snoozes: [snooze]),
        at: [2026, 11, 25],
      );
      expect(
        plan.notifications.where((n) => n.fireOn == day(2026, 12, 7)),
        hasLength(1),
      );
    });
  });

  group('the 64 cap', () {
    List<ReminderItem> returnsFrom(int count) => [
      for (var i = 0; i < count; i++)
        item('r$i', [deadline(returns, day(2026, 12, 1 + i))]),
    ];
    final prefs = only({returns, NotificationKind.weeklySummary});

    test('more than 64 candidates keep the 64 nearest deadline reminders', () {
      final plan = planAt(input(returnsFrom(40), preferences: prefs),
          at: [2026, 11, 25]);
      expect(plan.notifications, hasLength(64));
      // 40 items × 3 reminders + 4 weekly summaries.
      expect(plan.droppedCount, 124 - 64);
      expect(
        plan.notifications.every(
          (n) => n.priority == NotificationPriority.deadline,
        ),
        isTrue,
      );
      final ids = plan.notifications.map((n) => n.payload.itemId).toSet();
      expect(ids, contains('r0'));
      expect(ids, isNot(contains('r39')));
      final times = plan.notifications.map((n) => n.wallClock).toList();
      expect(times, orderedEquals([...times]..sort()));
    });

    test('other kinds only fill what deadlines leave, nearest first', () {
      final plan = planAt(input(returnsFrom(21), preferences: prefs),
          at: [2026, 11, 25]);
      expect(plan.notifications, hasLength(64));
      expect(plan.droppedCount, 3);
      final weekly = plan.notifications
          .where((n) => n.kind == NotificationKind.weeklySummary)
          .toList();
      expect(weekly.single.fireOn, day(2026, 11, 30));
    });

    test('a smaller capacity is honoured', () {
      final plan = planAt(input(returnsFrom(3), preferences: prefs),
          at: [2026, 11, 25], capacity: 2);
      expect(plan.notifications, hasLength(2));
      expect(plan.notifications.first.fireOn, day(2026, 11, 28));
    });

    test('platform IDs are unique, positive and 32-bit safe', () {
      final plan = planAt(input(returnsFrom(40), preferences: prefs),
          at: [2026, 11, 25]);
      final ids = plan.notifications.map((n) => n.platformId).toSet();
      expect(ids, hasLength(64));
      expect(ids.every((id) => id > 0 && id <= 0x7FFFFFFF), isTrue);
    });
  });

  group('determinism', () {
    test('the same input gives the same plan in the same order', () {
      final items = [
        item('b', [deadline(returns, day(2026, 12, 10))]),
        item('a', [deadline(returns, day(2026, 12, 10))]),
        item('c', [deadline(warranty, day(2026, 12, 10))]),
      ];
      final first = planAt(input(items), at: [2026, 11, 25]);
      final again = planAt(input(items.reversed.toList()), at: [2026, 11, 25]);
      expect(again.notifications, first.notifications);
      final sameMoment = first.notifications
          .where((n) => n.fireOn == day(2026, 12, 7))
          .map((n) => n.key)
          .toList();
      expect(sameMoment, orderedEquals([...sameMoment]..sort()));
    });

    test('keys name scope, kind, item, day and slot', () {
      final plan = planAt(
        input([item('r1', [deadline(returns, day(2026, 11, 27))])],
            preferences: returnsOnly, scope: user()),
        at: [2026, 11, 25],
      );
      expect(plan.notifications.map((n) => n.key), [
        '$projectKey/$userId|returnWindow|r1|2026-11-27|lead',
        '$projectKey/$userId|returnWindow|r1|2026-11-27|repeat',
      ]);
    });

    test('payloads carry the scope, item, deadline and item route', () {
      final plan = planAt(
        input([item('r1', [deadline(returns, day(2026, 11, 27))])],
            preferences: returnsOnly, scope: user()),
        at: [2026, 11, 25],
      );
      final payload = plan.notifications.first.payload;
      expect(payload.scope, user());
      expect(payload.kind, returns);
      expect(payload.itemId, 'r1');
      expect(payload.deadline, day(2026, 11, 27));
      expect(payload.route, '/vault/item/r1');
    });
  });

  group('copy detail', () {
    final items = [
      item('r1', [deadline(returns, day(2026, 11, 27))], name: 'Earbuds'),
    ];

    test('hide details never shows the item name', () {
      final prefs = returnsOnly.withShared(
        lockScreen: LockScreenDetail.hideDetails,
      );
      final plan = planAt(input(items, preferences: prefs), at: [2026, 11, 25]);
      for (final n in plan.notifications) {
        expect(n.text.title, 'Paper Drawer has a reminder');
        expect('${n.text.title} ${n.text.body}', isNot(contains('Earbuds')));
      }
    });

    test('another account on a shared phone gets deadlines with neutral text',
        () {
      final plan = planAt(
        input(
          [
            ...items,
            item('u1', const [], savedOn: day(2026, 11, 25), isUnfinished: true),
          ],
          scope: user(),
          forOtherAccount: true,
        ),
        at: [2026, 11, 25],
      );
      expect(plan.notifications, isNotEmpty);
      for (final n in plan.notifications) {
        expect(n.priority, NotificationPriority.deadline);
        expect(n.text.body,
            'A Paper Drawer deadline for another account is coming up.');
      }
    });
  });

  test('the next deadline is the nearest wanted one, fired or not', () {
    final plan = planAt(
      input([
        item('later', [deadline(warranty, day(2027, 3, 1))]),
        item('soon', [deadline(returns, day(2026, 11, 25))], name: 'Earbuds'),
        item('done', [deadline(returns, day(2026, 11, 25), done: true)]),
      ]),
      at: [2026, 11, 25, 20],
    );
    expect(plan.nextDeadline?.itemId, 'soon');
    expect(plan.nextDeadline?.deadline.kind, returns);
  });
}
