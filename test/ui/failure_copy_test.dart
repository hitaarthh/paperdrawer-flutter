import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrawer/core/failure/app_failure.dart';
import 'package:paperdrawer/core/failure/validation_issue.dart';
import 'package:paperdrawer/ui/core/failure_copy.dart';

void main() {
  final shown = <AppFailure>[
    for (final issue in ValidationIssue.values) ValidationFailure(issue),
    const NotFoundFailure('item', 'x'),
    const LimitReachedFailure(limit: 25, planName: 'base'),
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
      final text = FailureCopy.message(failure);
      final label = failure.debugDescription;
      expect(failure.isSilent, isFalse, reason: label);
      expect(text, isNotEmpty, reason: label);
      expect(text, isNot(contains('!')), reason: '$label: no exclamation marks');
      expect(text, isNot(contains("'")), reason: '$label: use ’ not \'');
      expect(text.trim(), text, reason: label);
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
      expect(FailureCopy.message(failure), isEmpty);
    }
  });

  test('the limit message says nothing is deleted', () {
    expect(
      FailureCopy.message(const LimitReachedFailure(limit: 25, planName: 'base')),
      contains('Nothing is deleted'),
    );
  });
}
