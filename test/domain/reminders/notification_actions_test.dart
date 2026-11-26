import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrawer/domain/account/account_scope.dart';
import 'package:paperdrawer/domain/item_status.dart';
import 'package:paperdrawer/domain/reminders/notification_actions.dart';
import 'package:paperdrawer/domain/reminders/notification_kind.dart';
import 'package:paperdrawer/domain/reminders/notification_payload.dart';
import 'package:paperdrawer/domain/reminders/other_account_reminders.dart';
import 'package:paperdrawer/domain/reminders/reminder_item.dart';
import 'package:paperdrawer/domain/reminders/window_kind.dart';

import 'reminder_fixtures.dart';

void main() {
  final resolver = NotificationActionResolver(clockAt(2026, 11, 27, 9));
  final payload = NotificationPayload(
    scope: user(),
    route: '/vault/item/abc',
    kind: NotificationKind.returnWindow,
    itemId: 'abc',
    deadline: day(2026, 11, 27),
  ).encode();

  ReminderCommand resolve(
    NotificationAction? action, {
    String? payloadText,
    AccountScope? active,
  }) => resolver.resolve(
    payload: payloadText ?? payload,
    actionId: action?.identifier,
    active: active ?? user(),
  );

  group('actions on a deadline notification', () {
    test('a tap opens the item', () {
      expect(resolve(null), const OpenRoute('/vault/item/abc'));
      expect(resolve(NotificationAction.openItem),
          const OpenRoute('/vault/item/abc'));
    });

    test('mark as done records the window and its end date', () {
      expect(
        resolve(NotificationAction.markDone),
        MarkDeadlineDone(
          'abc',
          DeadlineMark(NotificationKind.returnWindow, day(2026, 11, 27)),
        ),
      );
    });

    test('remind me tomorrow snoozes until the next day', () {
      final command = resolve(NotificationAction.remindTomorrow);
      expect(
        command,
        SnoozeDeadline(
          ReminderSnooze(
            itemId: 'abc',
            kind: NotificationKind.returnWindow,
            deadline: day(2026, 11, 27),
            until: day(2026, 11, 28),
          ),
        ),
      );
    });

    test('remind me tomorrow on 31 Dec rolls into the new year', () {
      final snooze = ReminderSnooze.tomorrow(
        itemId: 'x',
        kind: NotificationKind.warranty,
        deadline: day(2027, 1, 5),
        today: day(2026, 12, 31),
      );
      expect(snooze.until, day(2027, 1, 1));
    });

    test('mute this item mutes the whole item', () {
      expect(resolve(NotificationAction.muteItem), const MuteItem('abc'));
    });
  });

  group('responses that do nothing', () {
    test('another account’s notification never touches this drawer', () {
      expect(
        resolve(null, active: const GuestScope()),
        const IgnoreNotification(IgnoreReason.otherAccount),
      );
      expect(
        resolve(NotificationAction.markDone, active: const GuestScope()),
        const IgnoreNotification(IgnoreReason.otherAccount),
      );
    });

    test('an unreadable payload is ignored', () {
      expect(resolve(null, payloadText: 'garbage'),
          const IgnoreNotification(IgnoreReason.unreadable));
    });

    test('an unknown action is ignored', () {
      expect(
        resolver.resolve(payload: payload, actionId: 'pd.dance', active: user()),
        const IgnoreNotification(IgnoreReason.unknownAction),
      );
    });

    test('a design-v1 payload can open and mute but not mark done', () {
      const legacy = '/vault/item/abc';
      const guest = GuestScope();
      expect(resolve(null, payloadText: legacy, active: guest),
          const OpenRoute(legacy));
      expect(resolve(NotificationAction.muteItem,
              payloadText: legacy, active: guest),
          const MuteItem('abc'));
      expect(resolve(NotificationAction.markDone,
              payloadText: legacy, active: guest),
          const IgnoreNotification(IgnoreReason.missingTarget));
      expect(resolve(NotificationAction.remindTomorrow,
              payloadText: legacy, active: guest),
          const IgnoreNotification(IgnoreReason.missingTarget));
    });
  });

  test('categories carry the board’s actions', () {
    expect(NotificationCategory.deadline.actions, NotificationAction.values);
    expect(NotificationCategory.item.actions,
        [NotificationAction.openItem, NotificationAction.muteItem]);
    expect(NotificationCategory.general.actions, isEmpty);
    for (final action in NotificationAction.values) {
      expect(NotificationAction.byIdentifier(action.identifier), action);
    }
    expect(NotificationAction.openItem.opensApp, isTrue);
    expect(NotificationAction.markDone.opensApp, isFalse);
  });

  test('other accounts’ reminders are kept with neutral text by default', () {
    expect(OtherAccountReminders.current, OtherAccountReminders.keepNeutral);
  });

  group('window types and kinds', () {
    test('map both ways for every deadline', () {
      for (final type in WindowType.values) {
        expect(type.notificationKind.windowType, type);
        expect(type.notificationKind.isDeadline, isTrue);
      }
      expect(WindowType.componentWarranty.notificationKind,
          NotificationKind.partWarranty);
      expect(WindowType.policyYear.notificationKind,
          NotificationKind.policyRenewal);
      expect(WindowType.term.notificationKind, NotificationKind.agreementTerm);
      for (final kind in NotificationKind.values) {
        expect(kind.windowType == null, !kind.isDeadline, reason: kind.name);
      }
    });

    test('a cover window becomes a planner deadline', () {
      final window = CoverWindow(
        type: WindowType.componentWarranty,
        start: day(2025, 1, 1),
        end: day(2030, 1, 1),
        renews: false,
        component: 'Compressor',
      );
      final d = deadlineFromWindow(window, done: true);
      expect(d.kind, NotificationKind.partWarranty);
      expect(d.date, day(2030, 1, 1));
      expect(d.partName, 'Compressor');
      expect(d.done, isTrue);
    });
  });
}
