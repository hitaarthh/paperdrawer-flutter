import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrawer/core/failure/app_failure.dart';
import 'package:paperdrawer/core/failure/validation_issue.dart';
import 'package:paperdrawer/domain/reminders/item_reminder_setting.dart';
import 'package:paperdrawer/domain/reminders/notification_kind.dart';
import 'package:paperdrawer/domain/reminders/notification_preferences.dart';
import 'package:paperdrawer/domain/reminders/reminder_item.dart';
import 'package:paperdrawer/domain/reminders/reminder_time.dart';

void main() {
  const returns = NotificationKind.returnWindow;
  const warranty = NotificationKind.warranty;
  const term = NotificationKind.agreementTerm;
  final prefs = NotificationPreferences.defaults();

  group('lead times an item uses', () {
    test('my defaults follow Settings', () {
      expect(ItemReminderSetting.defaults.leadDaysFor(returns, prefs), [3, 0]);
      expect(ItemReminderSetting.defaults.leadDaysFor(term, prefs), isEmpty);
    });

    test('muted uses none', () {
      for (final kind in NotificationKind.deadlines) {
        expect(ItemReminderSetting.muted.leadDaysFor(kind, prefs), isEmpty);
      }
    });

    test('custom overrides its kinds and follows defaults for the rest', () {
      final custom = ItemReminderSetting.custom({
        returns: [1, 7],
        term: [30],
      }).requireValue;
      expect(custom.leadDaysFor(returns, prefs), [7, 1]);
      expect(custom.leadDaysFor(term, prefs), [30]);
      expect(custom.leadDaysFor(warranty, prefs), [30, 7]);
    });
  });

  group('custom validation', () {
    test('a lead time outside the choices is refused', () {
      expect(
        ItemReminderSetting.custom({
          returns: [2],
        }).failureOrNull,
        const ValidationFailure(
          ValidationIssue.leadTimeInvalid,
          field: 'returnWindow',
        ),
      );
    });

    test('a kind that is not a deadline is refused', () {
      expect(
        ItemReminderSetting.custom({
          NotificationKind.weeklySummary: [1],
        }).isErr,
        isTrue,
      );
    });
  });

  group('stored form', () {
    test('every mode survives a round trip', () {
      final settings = [
        ItemReminderSetting.defaults,
        ItemReminderSetting.muted,
        ItemReminderSetting.custom({returns: [3, 0], warranty: []})
            .requireValue,
        ItemReminderSetting.custom(
          const {},
          once: OnceReminder(
            DateTime.utc(2028, 2, 29),
            ReminderTime.of(20, 15).requireValue,
          ),
        ).requireValue,
      ];
      for (final setting in settings) {
        expect(
          ItemReminderSetting.decode(setting.encode()).requireValue,
          setting,
        );
      }
    });

    test('the stored JSON is versioned and readable', () {
      expect(ItemReminderSetting.muted.encode(), '{"v":1,"mode":"muted"}');
      expect(
        ItemReminderSetting.custom({returns: [0, 3]}).requireValue.encode(),
        '{"v":1,"mode":"custom","lead":{"returnWindow":[3,0]}}',
      );
    });

    test('an empty column means my defaults', () {
      expect(ItemReminderSetting.decode(null).requireValue,
          ItemReminderSetting.defaults);
      expect(ItemReminderSetting.decode('').requireValue,
          ItemReminderSetting.defaults);
    });

    test('anything malformed is a settingInvalid failure', () {
      for (final bad in [
        'nope',
        '{"v":2,"mode":"muted"}',
        '{"v":1,"mode":"loud"}',
        '{"v":1,"mode":"custom","lead":{"returnWindow":[2]}}',
        '{"v":1,"mode":"custom","lead":{"unknown":[3]}}',
        '{"v":1,"mode":"custom","lead":{"returnWindow":["3"]}}',
        '{"v":1,"mode":"custom","lead":{},"once":"2026-02-30T09:00"}',
      ]) {
        expect(
          ItemReminderSetting.decode(bad).failureOrNull,
          const ValidationFailure(
            ValidationIssue.settingInvalid,
            field: 'reminders',
          ),
          reason: bad,
        );
      }
    });
  });

  group('design-v1 columns', () {
    test('remind = 0 is muted', () {
      expect(
        ItemReminderSetting.fromLegacy(remind: false),
        ItemReminderSetting.muted,
      );
      expect(
        ItemReminderSetting.fromLegacy(
          remind: false,
          reminderAtLocal: DateTime(2026, 12, 1, 9),
        ),
        ItemReminderSetting.muted,
      );
    });

    test('no reminder_at keeps my defaults', () {
      expect(
        ItemReminderSetting.fromLegacy(remind: true),
        ItemReminderSetting.defaults,
      );
    });

    test('reminder_at becomes a one-off at its local time and no leads', () {
      final setting = ItemReminderSetting.fromLegacy(
        remind: true,
        reminderAtLocal: DateTime(2026, 12, 31, 23, 45),
      );
      final custom = setting as ItemRemindersCustom;
      expect(custom.once?.date, DateTime.utc(2026, 12, 31));
      expect(custom.once?.time.stored, '23:45');
      for (final kind in NotificationKind.deadlines) {
        expect(custom.leadDaysFor(kind, prefs), isEmpty);
      }
    });
  });

  group('done marks', () {
    test('a mark matches only its kind and end date', () {
      final mark = DeadlineMark(returns, DateTime.utc(2026, 11, 27));
      expect(
        mark.matches(
          ReminderDeadline(kind: returns, date: DateTime.utc(2026, 11, 27)),
        ),
        isTrue,
      );
      expect(
        mark.matches(
          ReminderDeadline(kind: returns, date: DateTime.utc(2026, 11, 28)),
        ),
        isFalse,
      );
      expect(
        mark.matches(
          ReminderDeadline(kind: warranty, date: DateTime.utc(2026, 11, 27)),
        ),
        isFalse,
      );
    });

    test('a mark survives its stored form', () {
      final mark = DeadlineMark(warranty, DateTime.utc(2028, 2, 29));
      expect(mark.stored, 'warranty@2028-02-29');
      expect(DeadlineMark.parse(mark.stored), mark);
      expect(DeadlineMark.parse('warranty@2027-02-29'), isNull);
      expect(DeadlineMark.parse('weeklySummary@2027-02-01'), isNull);
      expect(DeadlineMark.parse('nonsense'), isNull);
    });
  });
}
