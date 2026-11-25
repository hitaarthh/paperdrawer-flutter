import '../../core/failure/app_failure.dart';
import '../../core/failure/validation_issue.dart';

/// The words the user sees for each failure.
///
/// The only place failure copy lives. The `switch` over the sealed
/// [AppFailure] is exhaustive, so a new failure type can't ship without copy.
///
/// Copy rules (design system "Content"): short, calm, sentence case, second
/// person, say what to do next, typographic apostrophe (’), no exclamation
/// marks, never blame the user, never show codes or raw errors.
abstract final class FailureCopy {
  static String message(AppFailure failure) => switch (failure) {
    ValidationFailure(:final issue) => validation(issue),
    NotFoundFailure() => 'This item is no longer in your drawer.',
    LimitReachedFailure(:final limit) =>
      '$limit of $limit items on Base. Archive an old item or upgrade to add more. Nothing is deleted.',
    StorageFailure(:final kind) => switch (kind) {
      StorageFailureKind.full =>
        'Your iPhone is out of space. Free some up and try again. Nothing you typed is lost.',
      StorageFailureKind.unreadable =>
        'Couldn’t read this file. Try another photo or PDF.',
      StorageFailureKind.unsupportedFile =>
        'Choose a photo or PDF up to 20 MB.',
      StorageFailureKind.writeFailed =>
        'Couldn’t save that. Try again.',
      StorageFailureKind.corrupt =>
        'Part of your drawer couldn’t be read. Your other papers are safe.',
    },
    PermissionFailure(:final permission, :final permanentlyDenied) =>
      _permission(permission, permanentlyDenied),
    NetworkFailure() =>
      'Needs internet. Try again when you’re online. Your drawer still works.',
    AuthFailure(:final kind) => switch (kind) {
      AuthFailureKind.cancelled => '',
      AuthFailureKind.invalidCredentials =>
        'That email and password don’t match.',
      AuthFailureKind.emailAlreadyUsed =>
        'There’s already an account with this email. Sign in instead.',
      AuthFailureKind.emailNotConfirmed =>
        'Confirm your email first. We sent you a link.',
      AuthFailureKind.sessionRejected =>
        'Sign in again to keep syncing. Your papers on this iPhone are safe.',
      AuthFailureKind.accountDeleted => 'This account was deleted.',
    },
    PurchaseFailure(:final kind) => switch (kind) {
      PurchaseFailureKind.cancelled => '',
      PurchaseFailureKind.pending =>
        'Waiting for approval. It unlocks as soon as it’s approved.',
      PurchaseFailureKind.notAllowed =>
        'Purchases are turned off on this iPhone in Screen Time.',
      PurchaseFailureKind.unavailable =>
        'This plan isn’t available in your App Store region yet.',
      PurchaseFailureKind.storeError =>
        'The App Store couldn’t finish that. You haven’t been charged. Try again.',
    },
    SyncFailure(:final reason) => syncPaused(reason),
    CancelledFailure() => '',
    ScopeClosedFailure() => '',
    UnexpectedFailure() =>
      'Something went wrong. Nothing was lost. Try again.',
  };

  static String validation(ValidationIssue issue) => switch (issue) {
    ValidationIssue.nameRequired => 'Add a name so you can find it later.',
    ValidationIssue.nameTooLong => 'Use a shorter name.',
    ValidationIssue.purchaseDateRequired => 'Add the date you bought it.',
    ValidationIssue.endDateRequired =>
      'Add the date it ends, renews or expires.',
    ValidationIssue.endBeforeStart => 'This date is before the start date.',
    ValidationIssue.partWarrantyIncomplete =>
      'Add both the part and the date its warranty ends.',
    ValidationIssue.amountInvalid => 'Enter the amount as a number.',
    ValidationIssue.currencyInvalid => 'Choose a currency.',
    ValidationIssue.emailInvalid => 'Check the email address.',
    ValidationIssue.passwordTooShort => 'Use at least 8 characters.',
    ValidationIssue.leadTimeInvalid => 'Choose when to be reminded.',
    ValidationIssue.timeOfDayInvalid => 'Choose a time of day.',
    ValidationIssue.settingInvalid => 'That setting couldn’t be saved.',
  };

  static String syncPaused(SyncPauseReason reason) => switch (reason) {
    SyncPauseReason.iCloudUnavailable =>
      'Sync paused. Turn on iCloud in Settings to keep syncing.',
    SyncPauseReason.iCloudFull =>
      'Sync paused. Your iCloud storage is full. New papers still save on this iPhone.',
    SyncPauseReason.iCloudAccountMismatch =>
      'Sync paused. This iPhone’s iCloud belongs to someone else.',
    SyncPauseReason.signInRequired =>
      'Sync paused. Sign in again to keep syncing.',
    SyncPauseReason.appUpdateRequired =>
      'Sync paused. Update PaperDrawer to keep syncing.',
    SyncPauseReason.offline => 'Offline. Syncs when you’re back online.',
  };

  static String _permission(DevicePermission permission, bool permanent) {
    final what = switch (permission) {
      DevicePermission.camera => 'the camera',
      DevicePermission.photos => 'your photos',
      DevicePermission.notifications => 'notifications',
    };
    return permanent
        ? 'PaperDrawer can’t use $what. Turn it on in Settings.'
        : 'PaperDrawer needs $what for this.';
  }
}
