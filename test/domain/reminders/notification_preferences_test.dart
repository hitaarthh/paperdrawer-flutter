import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrawer/core/failure/app_failure.dart';
import 'package:paperdrawer/core/failure/validation_issue.dart';
import 'package:paperdrawer/domain/plans/plan_policy.dart';
import 'package:paperdrawer/domain/reminders/lead_days.dart';
import 'package:paperdrawer/domain/reminders/notification_kind.dart';
import 'package:paperdrawer/domain/reminders/notification_preferences.dart';
import 'package:paperdrawer/domain/reminders/notification_settings_codec.dart';
import 'package:paperdrawer/domain/reminders/reminder_time.dart';

void main() {
  final defaults = NotificationPreferences.defaults();

  group('defaults', () {
    test('every kind starts from NotificationKind', () {
      for (final kind in NotificationKind.values) {
        expect(defaults[kind].on, kind.defaultOn, reason: kind.name);
        expect(defaults[kind].push, isTrue);
      }
      expect(defaults[NotificationKind.returnWindow].leadDays, [3, 0]);
      expect(defaults[NotificationKind.policyRenewal].leadDays, [30, 7, 1]);
      expect(defaults[NotificationKind.agreementTerm].on, isFalse);
      expect(defaults[NotificationKind.weeklySummary].leadDays, isEmpty);
    });

    test('shared controls match the spec', () {
      expect(defaults.timeOfDay, ReminderTime.nineAm);
      expect(defaults.lastDayRepeat, isTrue);
      expect(NotificationPreferences.lastDayRepeatTime.stored, '18:00');
      expect(defaults.timeSensitiveLastDay, isTrue);
      expect(defaults.lockScreen, LockScreenDetail.showNames);
      expect(defaults.emailCopies, isTrue);
    });
  });

  group('validation', () {
    test('lead times outside the choices are refused', () {
      final result = defaults.withKind(
        NotificationKind.warranty,
        leadDays: [2],
      );
      expect(
        result.failureOrNull,
        const ValidationFailure(
          ValidationIssue.leadTimeInvalid,
          field: 'warranty',
        ),
      );
    });

    test('a deadline kind that is on needs at least one lead time', () {
      final result = defaults.withKind(
        NotificationKind.returnWindow,
        leadDays: [],
      );
      expect(result.isErr, isTrue);
      expect(
        defaults
            .withKind(NotificationKind.returnWindow, on: false, leadDays: [])
            .isOk,
        isTrue,
      );
    });

    test('kinds that are not deadlines take no lead times', () {
      expect(
        defaults.withKind(NotificationKind.weeklySummary, leadDays: [1]).isErr,
        isTrue,
      );
    });

    test('lead times are stored unique and furthest first', () {
      final prefs = defaults
          .withKind(NotificationKind.warranty, leadDays: [0, 30, 7, 30])
          .requireValue;
      expect(prefs[NotificationKind.warranty].leadDays, [30, 7, 0]);
    });

    test('a time of day outside 00:00–23:59 is refused', () {
      expect(
        defaults.withTimeOfDay(24, 0).failureOrNull,
        const ValidationFailure(
          ValidationIssue.timeOfDayInvalid,
          field: 'timeOfDay',
        ),
      );
      expect(defaults.withTimeOfDay(23, 60).isErr, isTrue);
      expect(defaults.withTimeOfDay(0, 0).isOk, isTrue);
      expect(defaults.withTimeOfDay(-1, 0).isErr, isTrue);
    });
  });

  group('channels come from the plan', () {
    const warranty = NotificationKind.warranty;

    test('Base and Essential push only; Pro adds email', () {
      expect(defaults.channelsFor(warranty, const BasePolicy()),
          {NotificationChannel.push});
      expect(defaults.channelsFor(warranty, const EssentialPolicy()),
          {NotificationChannel.push});
      expect(defaults.channelsFor(warranty, const ProPolicy()),
          {NotificationChannel.push, NotificationChannel.email});
    });

    test('email copies off removes email everywhere', () {
      final prefs = defaults.withShared(emailCopies: false);
      expect(prefs.channelsFor(warranty, const ProPolicy()),
          {NotificationChannel.push});
    });

    test('a kind that is off has no channels', () {
      final prefs = defaults.withKind(warranty, on: false).requireValue;
      expect(prefs.channelsFor(warranty, const ProPolicy()), isEmpty);
    });

    test('a kind the plan does not offer is never on', () {
      expect(defaults.isOn(NotificationKind.backupReminder, const ProPolicy()),
          isFalse);
      expect(defaults.isOn(NotificationKind.backupReminder, const BasePolicy()),
          isTrue);
      expect(defaults.isOn(NotificationKind.syncProblem, const BasePolicy()),
          isFalse);
      expect(
        defaults.channelsFor(NotificationKind.syncProblem, const BasePolicy()),
        isEmpty,
      );
    });

    test('unfinished items never email', () {
      expect(
        defaults.channelsFor(NotificationKind.unfinishedItem, const ProPolicy()),
        {NotificationChannel.push},
      );
    });
  });

  group('settings rows', () {
    test('every preference survives a round trip', () {
      final prefs = defaults
          .withKind(NotificationKind.returnWindow, leadDays: [7, 1, 0])
          .requireValue
          .withKind(NotificationKind.agreementTerm, on: true, email: false)
          .requireValue
          .withKind(NotificationKind.tips, on: true, push: false)
          .requireValue
          .withTimeOfDay(7, 30)
          .requireValue
          .withShared(
            lastDayRepeat: false,
            timeSensitiveLastDay: false,
            lockScreen: LockScreenDetail.hideDetails,
            emailCopies: false,
          );
      final rows = NotificationSettingsCodec.encode(prefs);
      expect(rows.keys.toList(), NotificationSettingsCodec.keys);
      expect(rows['notifications.returnWindow.lead_days'], '7,1,0');
      expect(rows['notifications.time_of_day'], '07:30');
      expect(rows['notifications.lock_screen'], 'hide_details');
      final decoded = NotificationSettingsCodec.decode(rows);
      expect(decoded.preferences, prefs);
      expect(decoded.invalidKeys, isEmpty);
    });

    test('missing rows keep the defaults', () {
      final decoded = NotificationSettingsCodec.decode(const {});
      expect(decoded.preferences, defaults);
      expect(decoded.invalidKeys, isEmpty);
    });

    test('malformed rows keep their defaults and are reported by key', () {
      final decoded = NotificationSettingsCodec.decode(const {
        'notifications.warranty.lead_days': '30,2',
        'notifications.time_of_day': '25:00',
        'notifications.lock_screen': 'sometimes',
        'notifications.email_copies': 'yes',
        'notifications.returnWindow.lead_days': '',
      });
      expect(decoded.preferences, defaults);
      expect(decoded.invalidKeys, [
        'notifications.email_copies',
        'notifications.lock_screen',
        'notifications.returnWindow.lead_days',
        'notifications.time_of_day',
        'notifications.warranty.lead_days',
      ]);
    });
  });

  group('design-v1 migration', () {
    test('a chosen lead time N becomes [N] for every deadline kind', () {
      final prefs = NotificationSettingsCodec.fromLegacy(legacyLeadDays: 7);
      for (final kind in NotificationKind.deadlines) {
        expect(prefs[kind].leadDays, [7], reason: kind.name);
        expect(prefs[kind].on, kind.defaultOn);
      }
    });

    test('2 days, which is no longer offered, becomes 3', () {
      final prefs = NotificationSettingsCodec.fromLegacy(legacyLeadDays: 2);
      expect(prefs[NotificationKind.returnWindow].leadDays, [3]);
    });

    test('no stored lead time keeps the new defaults', () {
      expect(NotificationSettingsCodec.fromLegacy(), defaults);
    });

    test('email_reminders carries over to email copies', () {
      expect(
        NotificationSettingsCodec.fromLegacy(legacyEmailReminders: false)
            .emailCopies,
        isFalse,
      );
    });

    test('legacy values map to the nearest earlier warning', () {
      expect(migrateLegacyLeadDays(1), 1);
      expect(migrateLegacyLeadDays(2), 3);
      expect(migrateLegacyLeadDays(10), 14);
      expect(migrateLegacyLeadDays(30), 30);
      expect(migrateLegacyLeadDays(45), 30);
    });
  });

  group('lead-day strings', () {
    test('decode refuses anything outside the choices', () {
      expect(decodeLeadDays('30, 7 ,0'), [30, 7, 0]);
      expect(decodeLeadDays(''), isEmpty);
      expect(decodeLeadDays('7,x'), isNull);
      expect(decodeLeadDays('5'), isNull);
      expect(encodeLeadDays([30, 7, 0]), '30,7,0');
    });
  });
}
