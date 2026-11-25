import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrawer/domain/plans/plan.dart';
import 'package:paperdrawer/domain/plans/plan_policy.dart';
import 'package:paperdrawer/domain/reminders/notification_kind.dart';

void main() {
  test('every plan has a policy that reports its own plan', () {
    for (final plan in Plan.values) {
      expect(PlanPolicy.of(plan).plan, plan);
    }
  });

  test('plans are ordered and include the ones below', () {
    expect(Plan.pro.includes(Plan.essential), isTrue);
    expect(Plan.essential.includes(Plan.pro), isFalse);
    expect(Plan.highest([Plan.essential, Plan.base, Plan.pro]), Plan.pro);
    expect(Plan.highest(const []), Plan.base);
  });

  group('Base', () {
    final base = PlanPolicy.of(Plan.base);

    test('no account, no sync, 25 items with a warning from 20', () {
      expect(base.requiresAccount, isFalse);
      expect(base.signInMethods, isEmpty);
      expect(base.syncKind, SyncKind.none);
      expect(base.survivesAppDeletion, isFalse);
      expect(base.itemLimit, const ItemLimit(max: 25, warnFrom: 20));
    });

    test('offers the backup reminder, not sync problems', () {
      expect(base.notificationKinds, contains(NotificationKind.backupReminder));
      expect(
        base.notificationKinds,
        isNot(contains(NotificationKind.syncProblem)),
      );
    });

    test('push only', () {
      expect(base.channelsFor(NotificationKind.warranty), {
        NotificationChannel.push,
      });
    });
  });

  group('Essential', () {
    final essential = PlanPolicy.of(Plan.essential);

    test('Sign in with Apple, iCloud sync, no limit, no website', () {
      expect(essential.requiresAccount, isTrue);
      expect(essential.signInMethods, {SignInMethod.apple});
      expect(essential.syncKind, SyncKind.iCloud);
      expect(essential.itemLimit, isNull);
      expect(essential.hasWebsiteVault, isFalse);
      expect(essential.survivesAppDeletion, isTrue);
    });

    test('offers sync problems, not the backup reminder; no email', () {
      expect(essential.notificationKinds, contains(NotificationKind.syncProblem));
      expect(
        essential.notificationKinds,
        isNot(contains(NotificationKind.backupReminder)),
      );
      expect(
        essential.channelsFor(NotificationKind.warranty),
        {NotificationChannel.push},
      );
    });
  });

  group('Pro', () {
    final pro = PlanPolicy.of(Plan.pro);

    test('PaperDrawer cloud, website, email reminders', () {
      expect(pro.syncKind, SyncKind.paperDrawerCloud);
      expect(pro.hasWebsiteVault, isTrue);
      expect(pro.hasEmailReminders, isTrue);
      expect(pro.signInMethods, containsAll([SignInMethod.apple, SignInMethod.email]));
    });

    test('email for deadlines and the weekly summary only', () {
      expect(pro.channelsFor(NotificationKind.policyRenewal), {
        NotificationChannel.push,
        NotificationChannel.email,
      });
      expect(pro.channelsFor(NotificationKind.weeklySummary), contains(NotificationChannel.email));
      expect(pro.channelsFor(NotificationKind.syncProblem), {NotificationChannel.push});
    });

    test('a kind the plan does not offer has no channels', () {
      expect(pro.channelsFor(NotificationKind.backupReminder), isEmpty);
    });
  });

  test('every deadline kind is offered on every plan', () {
    for (final plan in Plan.values) {
      expect(
        PlanPolicy.of(plan).notificationKinds,
        containsAll(NotificationKind.deadlines),
      );
    }
  });

  test('default lead times use only offered choices', () {
    for (final kind in NotificationKind.values) {
      for (final days in kind.defaultLeadDays) {
        expect(NotificationKind.leadDayChoices, contains(days), reason: kind.name);
      }
      if (kind.isDeadline) expect(kind.defaultLeadDays, isNotEmpty, reason: kind.name);
    }
  });
}
