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
///
/// Built once per app with the device noun ("iPhone", "iPad", "Mac") and the
/// limits the copy mentions, so nothing here goes stale when they change.
final class FailureCopy {
  const FailureCopy({
    this.deviceNoun = 'iPhone',
    this.maxAttachmentMegabytes = 20,
  });

  final String deviceNoun;
  final int maxAttachmentMegabytes;

  /// The message for [failure], or `null` for silent failures (show nothing).
  String? message(AppFailure failure) => switch (failure) {
    ValidationFailure(:final issue) => validation(issue),
    NotFoundFailure(:final entity) => switch (entity) {
      'attachment' => 'This file is no longer attached.',
      _ => 'This item is no longer in your drawer.',
    },
    LimitReachedFailure(:final limit, :final count, :final toArchive) =>
      count > limit
          ? '$count items, and Base keeps $limit. Archive $toArchive or upgrade to add more. Nothing is deleted.'
          : '$limit of $limit items on Base. Archive an old item or upgrade to add more. Nothing is deleted.',
    StorageFailure(:final kind) => switch (kind) {
      StorageFailureKind.full =>
        'Your $deviceNoun is out of space. Free some up and try again. Nothing you typed is lost.',
      StorageFailureKind.unreadable =>
        'Couldn’t read this file. Try another photo or PDF.',
      StorageFailureKind.unsupportedFile =>
        'Choose a photo or PDF up to $maxAttachmentMegabytes MB.',
      StorageFailureKind.busy => 'Your drawer is busy. Try again.',
      StorageFailureKind.constraintViolated =>
        'Couldn’t save that. Nothing was changed.',
      StorageFailureKind.writeFailed => 'Couldn’t save that. Try again.',
      StorageFailureKind.corrupt =>
        'Part of your drawer couldn’t be read. Your other papers are safe.',
    },
    PermissionFailure(:final permission, :final permanentlyDenied) =>
      _permission(permission, permanentlyDenied),
    NetworkFailure() =>
      'Needs internet. Try again when you’re online. Your drawer still works.',
    AuthFailure(:final kind) => switch (kind) {
      AuthFailureKind.cancelled => null,
      AuthFailureKind.invalidCredentials =>
        'That email and password don’t match.',
      AuthFailureKind.emailAlreadyUsed =>
        'There’s already an account with this email. Sign in instead.',
      AuthFailureKind.emailNotConfirmed =>
        'Confirm your email first. We sent you a link.',
      AuthFailureKind.sessionRejected =>
        'Sign in again to keep syncing. Your papers on this $deviceNoun are safe.',
      AuthFailureKind.accountDeleted => 'This account was deleted.',
      AuthFailureKind.rateLimited =>
        'Too many tries. Wait a minute and try again.',
      AuthFailureKind.appleUnavailable =>
        'Sign in with Apple isn’t available on this $deviceNoun. Use email instead.',
    },
    PurchaseFailure(:final kind) => switch (kind) {
      PurchaseFailureKind.cancelled => null,
      PurchaseFailureKind.pending =>
        'Waiting for approval. It unlocks as soon as it’s approved.',
      PurchaseFailureKind.notAllowed =>
        'Purchases are turned off on this $deviceNoun in Screen Time.',
      PurchaseFailureKind.unavailable =>
        'This plan isn’t available in your App Store region yet.',
      PurchaseFailureKind.belongsToAnotherAccount =>
        'This purchase belongs to another PaperDrawer account. Sign in to that account to use it.',
      PurchaseFailureKind.storeError =>
        'The App Store couldn’t finish that. You haven’t been charged. Try again.',
    },
    SyncFailure(:final reason) => syncPaused(reason),
    CancelledFailure() => null,
    ScopeClosedFailure() => null,
    UnexpectedFailure() => 'Something went wrong. Nothing was lost. Try again.',
  };

  String validation(ValidationIssue issue) => switch (issue) {
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

  String syncPaused(SyncPauseReason reason) => switch (reason) {
    SyncPauseReason.iCloudUnavailable =>
      'Sync paused. Turn on iCloud in Settings to keep syncing.',
    SyncPauseReason.iCloudFull =>
      'Sync paused. Your iCloud storage is full. New papers still save on this $deviceNoun.',
    SyncPauseReason.iCloudAccountMismatch =>
      'Sync paused. This $deviceNoun’s iCloud belongs to someone else.',
    SyncPauseReason.signInRequired =>
      'Sync paused. Sign in again to keep syncing.',
    SyncPauseReason.appUpdateRequired =>
      'Sync paused. Update PaperDrawer to keep syncing.',
    SyncPauseReason.offline => 'Offline. Syncs when you’re back online.',
  };

  String _permission(DevicePermission permission, bool permanent) {
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
