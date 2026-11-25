import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrawer/domain/plans/plan.dart';
import 'package:paperdrawer/domain/plans/plan_change.dart';

void main() {
  List<PlanChangeStep> steps(Plan from, Plan to, {bool guest = false}) =>
      PlanChange.between(from, to, isGuest: guest).steps;

  test('no change, no steps', () {
    for (final plan in Plan.values) {
      expect(steps(plan, plan), isEmpty);
    }
  });

  test('guest Base → Essential: Apple sign-in, offer move, iCloud upload', () {
    expect(steps(Plan.base, Plan.essential, guest: true), const [
      RequireSignIn({SignInMethod.apple}),
      OfferMoveGuestItems(),
      StartSyncWithFullUpload(SyncKind.iCloud),
    ]);
  });

  test('guest Base → Pro: sign-in, offer move, cloud upload', () {
    expect(steps(Plan.base, Plan.pro, guest: true), const [
      RequireSignIn({SignInMethod.apple, SignInMethod.email}),
      OfferMoveGuestItems(),
      StartSyncWithFullUpload(SyncKind.paperDrawerCloud),
    ]);
  });

  test('signed-in Base → Essential: no sign-in, no move', () {
    expect(steps(Plan.base, Plan.essential), const [
      StartSyncWithFullUpload(SyncKind.iCloud),
    ]);
  });

  test('Essential → Pro: stop iCloud, then full cloud upload', () {
    expect(steps(Plan.essential, Plan.pro), const [
      StopSync(SyncKind.iCloud),
      StartSyncWithFullUpload(SyncKind.paperDrawerCloud),
    ]);
  });

  test('Pro ends, Essential owned: back to iCloud, website read-only', () {
    expect(steps(Plan.pro, Plan.essential), const [
      StopSync(SyncKind.paperDrawerCloud),
      StartSyncWithFullUpload(SyncKind.iCloud),
      WebsiteBecomesReadOnly(),
    ]);
  });

  test('Pro ends, no Essential: stop sync, website read-only', () {
    expect(steps(Plan.pro, Plan.base), const [
      StopSync(SyncKind.paperDrawerCloud),
      WebsiteBecomesReadOnly(),
    ]);
  });

  test('Essential refunded: stop iCloud only', () {
    expect(steps(Plan.essential, Plan.base), const [StopSync(SyncKind.iCloud)]);
  });

  test('every change stops before it starts', () {
    for (final from in Plan.values) {
      for (final to in Plan.values) {
        final list = steps(from, to);
        final stop = list.indexWhere((s) => s is StopSync);
        final start = list.indexWhere((s) => s is StartSyncWithFullUpload);
        if (stop >= 0 && start >= 0) {
          expect(stop, lessThan(start), reason: '$from → $to');
        }
      }
    }
  });

  test('a guest who paid then got refunded: nothing to stop', () {
    expect(steps(Plan.essential, Plan.base, guest: true), isEmpty);
  });

  test('a guest moving between paid plans still signs in first', () {
    expect(steps(Plan.essential, Plan.pro, guest: true).first, isA<RequireSignIn>());
  });

  test('a paid guest who signs in: offer the move, then start sync', () {
    expect(PlanChange.finishAccountSetup(Plan.essential).steps, const [
      OfferMoveGuestItems(),
      StartSyncWithFullUpload(SyncKind.iCloud),
    ]);
    expect(PlanChange.finishAccountSetup(Plan.pro).steps.last,
        const StartSyncWithFullUpload(SyncKind.paperDrawerCloud));
  });

  test('upgrade and downgrade flags', () {
    expect(PlanChange.between(Plan.base, Plan.pro, isGuest: false).isUpgrade, isTrue);
    expect(PlanChange.between(Plan.pro, Plan.base, isGuest: false).isDowngrade, isTrue);
  });
}
