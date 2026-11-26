import 'package:purchases_flutter/purchases_flutter.dart' show PurchasesErrorCode;

import '../../core/failure/app_failure.dart';
import '../../core/failure/failure_mapper.dart';
import 'revenuecat_client.dart';

/// Maps RevenueCat errors to failures, for the purchase gateway's
/// [FailureMapper].
///
/// Every store error becomes a [PurchaseFailure]: codes listed below get
/// their kind, every other RevenueCat code is a retryable
/// [PurchaseFailureKind.storeError]. Connection problems are
/// [NetworkFailure]s. The cause kept is the content-free
/// [RevenueCatException].
///
/// A lookup table rather than a `switch`: `PurchasesErrorCode` belongs to the
/// plugin and grows between releases; a new code must fall back to
/// `storeError`, not break the build.
final class RevenueCatFailureRule implements FailureRule {
  const RevenueCatFailureRule();

  static const _offline = {
    PurchasesErrorCode.networkError,
    PurchasesErrorCode.offlineConnectionError,
  };

  static const _kinds = <PurchasesErrorCode, PurchaseFailureKind>{
    PurchasesErrorCode.purchaseCancelledError: PurchaseFailureKind.cancelled,
    PurchasesErrorCode.paymentPendingError: PurchaseFailureKind.pending,
    PurchasesErrorCode.purchaseNotAllowedError: PurchaseFailureKind.notAllowed,
    PurchasesErrorCode.insufficientPermissionsError:
        PurchaseFailureKind.notAllowed,
    // The App Store receipt is already attached to another PaperDrawer
    // account; purchases never move between accounts by themselves.
    PurchasesErrorCode.receiptAlreadyInUseError:
        PurchaseFailureKind.belongsToAnotherAccount,
    PurchasesErrorCode.productNotAvailableForPurchaseError:
        PurchaseFailureKind.unavailable,
    PurchasesErrorCode.ineligibleError: PurchaseFailureKind.unavailable,
    PurchasesErrorCode.storeProblemError: PurchaseFailureKind.storeError,
  };

  @override
  AppFailure? tryMap(Object error, StackTrace stackTrace) {
    if (error is! RevenueCatException) return null;
    if (_offline.contains(error.code)) {
      return NetworkFailure(cause: error, stackTrace: stackTrace);
    }
    return PurchaseFailure(
      _kinds[error.code] ?? PurchaseFailureKind.storeError,
      cause: error,
      stackTrace: stackTrace,
    );
  }
}
