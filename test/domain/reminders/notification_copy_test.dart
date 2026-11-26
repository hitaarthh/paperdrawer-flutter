import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrawer/core/failure/app_failure.dart';
import 'package:paperdrawer/domain/reminders/copy_dates.dart';
import 'package:paperdrawer/domain/reminders/notification_actions.dart';
import 'package:paperdrawer/domain/reminders/notification_copy.dart';
import 'package:paperdrawer/domain/reminders/notification_kind.dart';
import 'package:paperdrawer/domain/reminders/notification_subject.dart';
import 'package:paperdrawer/domain/reminders/reminder_item.dart';

import 'reminder_fixtures.dart';

void main() {
  NotificationText deadlineText(
    ReminderDeadline d,
    DateTime fireOn, {
    String name = 'Wireless earbuds',
    CopyDetail detail = CopyDetail.full,
  }) => NotificationCopy.text(
    DeadlineSubject(itemId: 'i', itemName: name, deadline: d, fireOn: fireOn),
    detail,
  );

  group('deadline copy matches the boards', () {
    final returnFri = deadline(NotificationKind.returnWindow, day(2026, 11, 27));

    test('return window, two days before (iOSNotifyReturns)', () {
      expect(
        deadlineText(returnFri, day(2026, 11, 25)),
        const NotificationText(
          'Return window closes in 2 days',
          'Wireless earbuds · return by Fri 27 Nov',
        ),
      );
    });

    test('return window, last day (iOSLockScreen)', () {
      expect(
        deadlineText(returnFri, day(2026, 11, 27)),
        const NotificationText(
          'Return window closes today',
          'Wireless earbuds · last day to return. Tap to see the bill.',
        ),
      );
    });

    test('return window, the day before', () {
      expect(deadlineText(returnFri, day(2026, 11, 26)).title,
          'Return window closes tomorrow');
    });

    test('policy renewal with a no-claim bonus (iOSLockScreen)', () {
      final policy = deadline(
        NotificationKind.policyRenewal,
        day(2026, 12, 7),
        renews: true,
        keepsNoClaimBonus: true,
      );
      expect(
        deadlineText(policy, day(2026, 11, 25), name: 'Family health policy'),
        const NotificationText(
          'Family health policy renews in 12 days',
          'Renew by Mon 7 Dec to keep your no-claim bonus.',
        ),
      );
    });

    test('policy renewal without a no-claim bonus, and an expiring policy', () {
      final renews = deadline(NotificationKind.policyRenewal, day(2026, 12, 7),
          renews: true);
      expect(deadlineText(renews, day(2026, 11, 30), name: 'Home cover').body,
          'Renew by Mon 7 Dec to stay covered.');
      final ends = deadline(NotificationKind.policyRenewal, day(2026, 12, 7));
      expect(
        deadlineText(ends, day(2026, 12, 7), name: 'Travel cover'),
        const NotificationText('Travel cover expires today',
            'Cover ends today.'),
      );
    });

    test('validity (iOSLockScreen: "Activa PUC ends in 30 days")', () {
      final puc = deadline(NotificationKind.validity, day(2027, 1, 2));
      expect(
        deadlineText(puc, day(2026, 12, 3), name: 'Activa PUC'),
        const NotificationText(
          'Activa PUC ends in 30 days',
          'Renew before Sat 2 Jan.',
        ),
      );
    });

    test('warranty and part warranty', () {
      final fridge = deadline(NotificationKind.warranty, day(2027, 11, 20));
      expect(
        deadlineText(fridge, day(2027, 10, 21), name: 'Samsung fridge'),
        const NotificationText(
          'Samsung fridge warranty ends in 30 days',
          'Book a service visit before Sat 20 Nov if anything needs fixing.',
        ),
      );
      final part = deadline(NotificationKind.partWarranty, day(2027, 11, 20),
          partName: 'Compressor');
      expect(deadlineText(part, day(2027, 10, 21), name: 'LG fridge').title,
          'LG fridge compressor warranty ends in 30 days');
      final acronym = deadline(NotificationKind.partWarranty,
          day(2027, 11, 20), partName: 'PCB');
      expect(deadlineText(acronym, day(2027, 11, 20), name: 'AC').title,
          'AC PCB warranty ends today');
      final unnamed = deadline(NotificationKind.partWarranty,
          day(2027, 11, 20));
      expect(deadlineText(unnamed, day(2027, 11, 19), name: 'AC').title,
          'AC part warranty ends tomorrow');
    });

    test('agreement terms that renew and that end', () {
      final rent = deadline(NotificationKind.agreementTerm, day(2027, 3, 31),
          renews: true);
      expect(deadlineText(rent, day(2027, 3, 1), name: 'Flat rent').title,
          'Flat rent renews in 30 days');
      final amc = deadline(NotificationKind.agreementTerm, day(2027, 3, 31));
      expect(
        deadlineText(amc, day(2027, 3, 31), name: 'AMC'),
        const NotificationText('AMC ends today', 'Ends today.'),
      );
    });

    test('a snooze past the end says it ended, honestly', () {
      expect(
        deadlineText(returnFri, day(2026, 11, 28)).title,
        'Wireless earbuds: return window ended yesterday',
      );
      expect(
        deadlineText(returnFri, day(2026, 11, 30)).title,
        'Wireless earbuds: return window ended on Fri 27 Nov',
      );
    });

    test('far-off dates show the year instead of the weekday', () {
      final far = deadline(NotificationKind.warranty, day(2027, 11, 20));
      expect(deadlineText(far, day(2026, 11, 25)).body,
          contains('before 20 Nov 2027'));
    });

    test('hidden detail and other accounts never show names', () {
      expect(
        deadlineText(returnFri, day(2026, 11, 25), detail: CopyDetail.hidden),
        const NotificationText(
          'Paper Drawer has a reminder',
          'Open your drawer to see what’s due.',
        ),
      );
      expect(
        deadlineText(returnFri, day(2026, 11, 25),
            detail: CopyDetail.otherAccount),
        const NotificationText(
          'Paper Drawer has a reminder',
          'A Paper Drawer deadline for another account is coming up.',
        ),
      );
    });
  });

  group('other kinds', () {
    DueEntry entry(String name, NotificationKind kind, {bool renews = false}) =>
        DueEntry(
          itemId: name,
          itemName: name,
          deadline: deadline(kind, day(2026, 11, 30), renews: renews),
        );

    test('weekly summary names up to three and counts the rest', () {
      NotificationText weekly(List<DueEntry> entries,
              [CopyDetail detail = CopyDetail.full]) =>
          NotificationCopy.text(
            WeeklySummarySubject(weekStart: day(2026, 11, 30), entries: entries),
            detail,
          );
      final four = [
        entry('Earbuds', NotificationKind.returnWindow),
        entry('Health policy', NotificationKind.policyRenewal, renews: true),
        entry('Activa PUC', NotificationKind.validity),
        entry('Kettle', NotificationKind.warranty),
      ];
      expect(
        weekly(four),
        const NotificationText(
          'This week in your drawer',
          '4 things due: Earbuds return, Health policy renewal and 2 more.',
        ),
      );
      expect(weekly(four.take(3).toList()).body,
          '3 things due: Earbuds return, Health policy renewal and Activa '
          'PUC renewal.');
      expect(weekly(four.take(1).toList()).body, '1 thing due: Earbuds return.');
      expect(weekly(four, CopyDetail.hidden).body,
          '4 things are due this week.');
    });

    test('unfinished item', () {
      expect(
        NotificationCopy.text(
          const UnfinishedItemSubject(itemId: 'm', itemName: 'Mixer'),
          CopyDetail.full,
        ).title,
        'Finish adding Mixer',
      );
      expect(
        NotificationCopy.text(
          const UnfinishedItemSubject(itemId: 'm', itemName: 'Mixer'),
          CopyDetail.hidden,
        ).body,
        isNot(contains('Mixer')),
      );
    });

    test('every sync reason has copy', () {
      for (final reason in SyncPauseReason.values) {
        final text = NotificationCopy.syncProblem(reason);
        expect(text.title, isNotEmpty);
        expect(text.body, isNotEmpty);
      }
    });
  });

  group('house style', () {
    test('no exclamation marks or straight apostrophes in any copy', () {
      final texts = <NotificationText>[
        for (final kind in NotificationKind.deadlines)
          for (final fire in [day(2026, 11, 1), day(2026, 11, 30),
              day(2026, 12, 1), day(2026, 12, 2)])
            for (final detail in CopyDetail.values)
              deadlineText(
                deadline(kind, day(2026, 12, 1), renews: fire.day.isEven),
                fire,
                detail: detail,
              ),
        for (final reason in SyncPauseReason.values)
          NotificationCopy.syncProblem(reason),
        NotificationCopy.text(
          const BackupSubject(daysSinceExport: null), CopyDetail.full),
        NotificationCopy.text(
          const BackupSubject(daysSinceExport: 90), CopyDetail.full),
        NotificationCopy.text(
          const OnceItemSubject(itemId: 'o', itemName: 'Lamp'), CopyDetail.full),
      ];
      for (final text in texts) {
        final all = '${text.title} ${text.body}';
        expect(all, isNot(contains('!')), reason: all);
        expect(all, isNot(contains("'")), reason: all);
      }
    });

    test('settings labels follow the boards', () {
      expect(NotificationCopy.kindName(NotificationKind.validity),
          'Validity ending');
      expect(NotificationCopy.leadSummary([3, 0]), '3 days, on the day');
      expect(NotificationCopy.leadSummary([30, 7]), '30, 7 days');
      expect(NotificationCopy.leadSummary([1, 7, 30]), '30, 7, 1 days');
      expect(NotificationCopy.leadSummary([1]), '1 day');
      expect(NotificationCopy.leadSummary([0]), 'On the day');
      expect(NotificationCopy.leadChip(0), 'On the day');
      expect(NotificationCopy.leadChip(14), '14 days');
      expect(
        [
          for (final a in NotificationCategory.deadline.actions)
            NotificationCopy.actionTitle(a),
        ],
        ['Mark as done', 'Remind me tomorrow', 'Open item', 'Mute this item'],
      );
    });

    test('dates read "Fri 27 Nov" near and "20 Nov 2027" far', () {
      expect(CopyDates.short(day(2026, 11, 27), day(2026, 11, 25)),
          'Fri 27 Nov');
      expect(CopyDates.short(day(2028, 2, 29), day(2028, 2, 1)), 'Tue 29 Feb');
      expect(CopyDates.short(day(2027, 11, 20), day(2026, 11, 25)),
          '20 Nov 2027');
      expect(CopyDates.weekday(day(2026, 11, 27)), 'Fri');
    });
  });
}
