import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrawer/core/failure/app_failure.dart';
import 'package:paperdrawer/core/failure/validation_issue.dart';
import 'package:paperdrawer/ui/core/failure_copy.dart';

void main() {
  const copy = FailureCopy();

  final shown = <AppFailure>[
    for (final issue in ValidationIssue.values) ValidationFailure(issue),
    const NotFoundFailure('item', 'x'),
    const NotFoundFailure('attachment', 'x'),
    const LimitReachedFailure(count: 25, limit: 25, planName: 'base'),
    const LimitReachedFailure(count: 40, limit: 25, planName: 'base'),
    for (final kind in StorageFailureKind.values) StorageFailure(kind),
    for (final permission in DevicePermission.values) ...[
      PermissionFailure(permission),
      PermissionFailure(permission, permanentlyDenied: true),
    ],
    const NetworkFailure(),
    for (final kind in AuthFailureKind.values)
      if (kind != AuthFailureKind.cancelled) AuthFailure(kind),
    for (final kind in PurchaseFailureKind.values)
      if (kind != PurchaseFailureKind.cancelled) PurchaseFailure(kind),
    for (final reason in SyncPauseReason.values) SyncFailure(reason),
    const UnexpectedFailure(),
  ];

  test('every non-silent failure has copy that follows the content rules', () {
    for (final failure in shown) {
      final text = copy.message(failure);
      final label = failure.debugDescription;
      expect(failure.isSilent, isFalse, reason: label);
      expect(text, isNotNull, reason: label);
      expect(text, isNotEmpty, reason: label);
      expect(text, isNot(contains('!')), reason: '$label: no exclamation marks');
      expect(text, isNot(contains("'")), reason: '$label: use ’ not \'');
      expect(text!.trim(), text, reason: label);
      expect(text[0], text[0].toUpperCase(), reason: '$label: sentence case');
      expect(text.endsWith('.'), isTrue, reason: label);
    }
  });

  test('silent failures have no copy', () {
    for (final failure in const <AppFailure>[
      CancelledFailure(),
      ScopeClosedFailure(),
      AuthFailure(AuthFailureKind.cancelled),
      PurchaseFailure(PurchaseFailureKind.cancelled),
    ]) {
      expect(failure.isSilent, isTrue);
      expect(copy.message(failure), isNull);
    }
  });

  test('the limit message says how many to archive after a downgrade', () {
    expect(
      copy.message(
        const LimitReachedFailure(count: 40, limit: 25, planName: 'base'),
      ),
      contains('Archive 16'),
    );
  });

  test('device-specific copy uses the device noun', () {
    const ipad = FailureCopy(deviceNoun: 'iPad');
    expect(
      ipad.message(const StorageFailure(StorageFailureKind.full)),
      contains('iPad'),
    );
  });
}
