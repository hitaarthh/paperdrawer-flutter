import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrawer/core/failure/app_failure.dart';
import 'package:paperdrawer/core/failure/validation_issue.dart';
import 'package:paperdrawer/domain/account/account_scope.dart';
import 'package:paperdrawer/domain/reminders/notification_id.dart';
import 'package:paperdrawer/domain/reminders/notification_kind.dart';
import 'package:paperdrawer/domain/reminders/notification_payload.dart';
import 'package:paperdrawer/domain/reminders/reminder_time.dart';

import 'reminder_fixtures.dart';

void main() {
  group('NotificationId', () {
    test('is FNV-1a 64 truncated to 53 bits (reference vectors)', () {
      // FNV-1a 64 of "" is 0xcbf29ce484222325, of "a" 0xaf63dc4c8601ec8c,
      // of "foobar" 0x85944171f73967e8; these are their low 53 bits.
      expect(NotificationId.stableId(''), 5239054864098085);
      expect(NotificationId.stableId('a'), 1086646154030220);
      expect(NotificationId.stableId('foobar'), 5701457269057512);
      expect(
        NotificationId.stableId('guest|returnWindow|item-1|2026-11-27|lead'),
        4049818906206601,
      );
      expect(NotificationId.stableId('ä→€'), 1270332984249888);
    });

    test('stays within 53 bits and is stable across calls', () {
      for (var i = 0; i < 500; i++) {
        final key = 'scope|warranty|item-$i|2026-12-01|lead';
        final id = NotificationId.stableId(key);
        expect(id, inInclusiveRange(0, NotificationId.maxStableId));
        expect(NotificationId.stableId(key), id);
      }
    });

    test('different keys give different IDs', () {
      final ids = {
        for (var i = 0; i < 2000; i++)
          NotificationId.stableId('guest|returnWindow|i$i|2026-11-27|lead'),
      };
      expect(ids, hasLength(2000));
    });

    test('platform IDs fit a signed 32-bit int and are never 0', () {
      expect(NotificationId.platformId(0), 1);
      expect(
        NotificationId.platformId(NotificationId.maxStableId),
        inInclusiveRange(1, NotificationId.maxPlatformId),
      );
      expect(NotificationId.platformId(1086646154030220), 101295398);
    });
  });

  group('NotificationPayload', () {
    final full = NotificationPayload(
      scope: user(),
      route: '/vault/item/abc',
      kind: NotificationKind.returnWindow,
      itemId: 'abc',
      deadline: day(2028, 2, 29),
    );

    test('round-trips every field', () {
      final encoded = full.encode();
      expect(encoded, startsWith('pd2;scope='));
      expect(NotificationPayload.parse(encoded), full);
    });

    test('round-trips the guest and a payload with only a route', () {
      const home = NotificationPayload(scope: GuestScope(), route: '/home');
      expect(home.encode(), 'pd2;scope=guest;route=%2Fhome');
      expect(NotificationPayload.parse(home.encode()), home);
    });

    test('percent-encodes values so separators inside them are safe', () {
      final odd = NotificationPayload(
        scope: const GuestScope(),
        route: '/vault/item/a;b=c|d',
        itemId: 'a;b=c|d',
      );
      expect(NotificationPayload.parse(odd.encode()), odd);
    });

    test('ignores unknown fields from a later version', () {
      final parsed = NotificationPayload.parse('${full.encode()};future=1');
      expect(parsed, full);
    });

    test('reads design-v1 payloads', () {
      expect(
        NotificationPayload.parse('/vault/item/abc'),
        const NotificationPayload(
          scope: GuestScope(),
          route: '/vault/item/abc',
          itemId: 'abc',
          version: 1,
        ),
      );
      final scoped = NotificationPayload.parse(
        '$projectKey/$userId|/vault/item/abc',
      );
      expect(scoped?.scope, user());
      expect(scoped?.itemId, 'abc');
      expect(scoped?.version, 1);
      expect(scoped?.kind, isNull);
      expect(
        NotificationPayload.parse('$projectKey/$userId|/claims/x')?.route,
        '/claims/x',
      );
    });

    test('refuses what it did not write', () {
      for (final bad in [
        null,
        '',
        'hello',
        'pd2;route=%2Fhome',
        'pd2;scope=guest',
        'pd2;scope=guest;route=home',
        'pd2;scope=guest;route=%2Fhome;kind=claim',
        'pd2;scope=guest;route=%2Fhome;date=2027-02-29',
        'pd2;scope=guest;route=%E0%A4',
        'pd2;scope=not-a-scope;route=%2Fhome',
        'nouuid|/vault/item/a',
      ]) {
        expect(NotificationPayload.parse(bad), isNull, reason: bad);
      }
    });

    test('opens only in the drawer it belongs to', () {
      expect(full.routeFor(user()), '/vault/item/abc');
      expect(full.routeFor(const GuestScope()), isNull);
    });

    test('scope keys match design-v1 DrawerOwner keys', () {
      expect(NotificationPayload.scopeKey(user()), '$projectKey/$userId');
      expect(NotificationPayload.parseScopeKey('$projectKey/$userId'), user());
      expect(NotificationPayload.parseScopeKey('guest'), const GuestScope());
    });
  });

  group('ReminderTime', () {
    test('parses, stores and labels', () {
      final time = ReminderTime.parse('9:05').requireValue;
      expect(time.stored, '09:05');
      expect(time.label12h, '9:05 AM');
      expect(ReminderTime.sixPm.label12h, '6:00 PM');
      expect(ReminderTime.of(0, 0).requireValue.label12h, '12:00 AM');
      expect(ReminderTime.of(12, 30).requireValue.label12h, '12:30 PM');
    });

    test('refuses impossible times', () {
      for (final bad in ['24:00', '12:60', '9', 'nine', '-1:00']) {
        expect(
          ReminderTime.parse(bad).failureOrNull,
          const ValidationFailure(
            ValidationIssue.timeOfDayInvalid,
            field: 'timeOfDay',
          ),
          reason: bad,
        );
      }
    });

    test('places a civil date at a floating wall-clock time', () {
      expect(
        ReminderTime.nineAm.on(day(2028, 2, 29)),
        DateTime.utc(2028, 2, 29, 9),
      );
      expect(wallClockOf(DateTime(2026, 11, 25, 8, 30)),
          DateTime.utc(2026, 11, 25, 8, 30));
    });
  });
}
