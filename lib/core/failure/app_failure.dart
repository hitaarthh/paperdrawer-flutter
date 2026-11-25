import 'package:flutter/foundation.dart';

import 'validation_issue.dart';

/// Every expected way an operation in PaperDrawer can fail.
///
/// Failures carry *codes*, never user-facing copy. The UI turns a failure into
/// words with `FailureCopy` (lib/ui/core/failure_copy.dart), whose `switch`
/// over this sealed hierarchy is exhaustive: adding a failure type without
/// copy is a compile error.
///
/// Rules:
/// - Add a new subclass only when callers must react differently to it.
///   Otherwise add a value to an existing `kind` enum.
/// - [isSilent] failures (the user cancelled, the account was switched) are
///   never shown as errors.
/// - [isRetryable] failures get a "Try again" action in the UI.
@immutable
sealed class AppFailure {
  const AppFailure({this.cause, this.stackTrace});

  /// The original error, kept for logs. Never shown to the user.
  final Object? cause;
  final StackTrace? stackTrace;

  /// True when retrying the same operation may succeed.
  bool get isRetryable => false;

  /// True when the UI should stay quiet (no snackbar, no error state).
  bool get isSilent => false;

  /// A short developer-facing description for logs and test output.
  ///
  /// Must never contain user content or the text of [cause].
  String get debugDescription => '$runtimeType';
}

/// Input that breaks a rule, such as a blank name or an end date before the
/// start date. Shown inline next to the field.
final class ValidationFailure extends AppFailure {
  const ValidationFailure(this.issue, {this.field});

  final ValidationIssue issue;

  /// The form field the issue belongs to, if any, so the UI can focus it.
  final String? field;

  @override
  String get debugDescription => 'ValidationFailure(${issue.name}, $field)';

  @override
  bool operator ==(Object other) =>
      other is ValidationFailure && other.issue == issue && other.field == field;

  @override
  int get hashCode => Object.hash(issue, field);
}

/// The record the user acted on no longer exists (deleted on another device,
/// or a stale screen).
final class NotFoundFailure extends AppFailure {
  const NotFoundFailure(this.entity, this.id);

  final String entity;
  final String id;

  @override
  String get debugDescription => 'NotFoundFailure($entity, $id)';

  @override
  bool operator ==(Object other) =>
      other is NotFoundFailure && other.entity == entity && other.id == id;

  @override
  int get hashCode => Object.hash(entity, id);
}

/// The active plan does not allow more items.
final class LimitReachedFailure extends AppFailure {
  const LimitReachedFailure({
    required this.count,
    required this.limit,
    required this.planName,
  });

  /// Active items now. Can exceed [limit] after a downgrade.
  final int count;
  final int limit;

  /// `Plan.name`, kept as a string so core does not depend on the domain.
  final String planName;

  /// How many items must be archived before one more fits.
  int get toArchive => count - limit + 1;

  @override
  String get debugDescription =>
      'LimitReachedFailure($planName, $count/$limit)';

  @override
  bool operator ==(Object other) =>
      other is LimitReachedFailure &&
      other.count == count &&
      other.limit == limit &&
      other.planName == planName;

  @override
  int get hashCode => Object.hash(count, limit, planName);
}

enum StorageFailureKind {
  /// The phone has no space left.
  full,

  /// A file exists but can't be read or decoded.
  unreadable,

  /// The type or size of a file is not accepted.
  unsupportedFile,

  /// The database was busy or locked by another connection. Retry.
  busy,

  /// A write broke a database rule (duplicate ID, missing parent). A bug or
  /// bad data, so retrying the same write won't help.
  constraintViolated,

  /// A database or file write failed for another reason.
  writeFailed,

  /// The database file is damaged or from a newer app version.
  corrupt,
}

/// Something went wrong reading or writing on the device.
final class StorageFailure extends AppFailure {
  const StorageFailure(this.kind, {super.cause, super.stackTrace});

  final StorageFailureKind kind;

  @override
  bool get isRetryable =>
      kind == StorageFailureKind.writeFailed || kind == StorageFailureKind.busy;

  /// Never includes [cause]: database errors embed SQL arguments (item names,
  /// amounts), which must not reach logs.
  @override
  String get debugDescription => 'StorageFailure(${kind.name})';

  @override
  bool operator ==(Object other) =>
      other is StorageFailure && other.kind == kind;

  @override
  int get hashCode => kind.hashCode;
}

enum DevicePermission { camera, photos, notifications }

/// The user hasn't granted a permission the action needs.
final class PermissionFailure extends AppFailure {
  const PermissionFailure(this.permission, {this.permanentlyDenied = false});

  final DevicePermission permission;

  /// True when iOS will not ask again, so the UI links to Settings.
  final bool permanentlyDenied;

  @override
  String get debugDescription =>
      'PermissionFailure(${permission.name}, permanent: $permanentlyDenied)';

  @override
  bool operator ==(Object other) =>
      other is PermissionFailure &&
      other.permission == permission &&
      other.permanentlyDenied == permanentlyDenied;

  @override
  int get hashCode => Object.hash(permission, permanentlyDenied);
}

/// A network call failed or timed out. Local work is never blocked by this.
final class NetworkFailure extends AppFailure {
  const NetworkFailure({this.timedOut = false, super.cause, super.stackTrace});

  final bool timedOut;

  @override
  bool get isRetryable => true;

  @override
  String get debugDescription => 'NetworkFailure(timedOut: $timedOut)';

  @override
  bool operator ==(Object other) =>
      other is NetworkFailure && other.timedOut == timedOut;

  @override
  int get hashCode => timedOut.hashCode;
}

enum AuthFailureKind {
  /// The user closed the Apple or Google sheet.
  cancelled,
  invalidCredentials,
  emailAlreadyUsed,
  emailNotConfirmed,

  /// The server rejected the saved session (password changed, revoked).
  sessionRejected,

  /// The account was deleted, possibly on the website.
  accountDeleted,
}

/// Sign-in, sign-up or session problems.
final class AuthFailure extends AppFailure {
  const AuthFailure(this.kind, {super.cause, super.stackTrace});

  final AuthFailureKind kind;

  @override
  bool get isSilent => kind == AuthFailureKind.cancelled;

  @override
  String get debugDescription => 'AuthFailure(${kind.name})';

  @override
  bool operator ==(Object other) => other is AuthFailure && other.kind == kind;

  @override
  int get hashCode => kind.hashCode;
}

enum PurchaseFailureKind {
  cancelled,

  /// Ask to Buy or a slow payment method: StoreKit reports "pending".
  pending,

  /// Purchases are disabled on this device (Screen Time).
  notAllowed,

  /// The product is not available in this storefront.
  unavailable,

  /// The store returned an error.
  storeError,
}

/// App Store or Play Store purchase problems.
final class PurchaseFailure extends AppFailure {
  const PurchaseFailure(this.kind, {super.cause, super.stackTrace});

  final PurchaseFailureKind kind;

  @override
  bool get isSilent => kind == PurchaseFailureKind.cancelled;

  @override
  bool get isRetryable => kind == PurchaseFailureKind.storeError;

  @override
  String get debugDescription => 'PurchaseFailure(${kind.name})';

  @override
  bool operator ==(Object other) =>
      other is PurchaseFailure && other.kind == kind;

  @override
  int get hashCode => kind.hashCode;
}

enum SyncPauseReason {
  /// iCloud is off or signed out on this device.
  iCloudUnavailable,

  /// The user's iCloud storage is full.
  iCloudFull,

  /// This device's iCloud belongs to someone other than the account owner.
  iCloudAccountMismatch,

  /// The saved session needs the user to sign in again.
  signInRequired,

  /// The server needs a newer version of the app.
  appUpdateRequired,

  /// No network right now. Resumes by itself.
  offline,
}

/// Sync could not run. Local data is unaffected; sync resumes by itself or
/// after the user fixes the [reason].
final class SyncFailure extends AppFailure {
  const SyncFailure(this.reason, {super.cause, super.stackTrace});

  final SyncPauseReason reason;

  @override
  bool get isRetryable => reason == SyncPauseReason.offline;

  @override
  String get debugDescription => 'SyncFailure(${reason.name})';

  @override
  bool operator ==(Object other) =>
      other is SyncFailure && other.reason == reason;

  @override
  int get hashCode => reason.hashCode;
}

/// The user backed out (closed a picker, cancelled a sheet). Never an error.
final class CancelledFailure extends AppFailure {
  const CancelledFailure();

  @override
  bool get isSilent => true;

  @override
  bool operator ==(Object other) => other is CancelledFailure;

  @override
  int get hashCode => (CancelledFailure).hashCode;
}

/// The account this work belonged to is no longer active (signed out or
/// switched). The result is dropped so nothing lands in another person's
/// drawer.
final class ScopeClosedFailure extends AppFailure {
  const ScopeClosedFailure();

  @override
  bool get isSilent => true;

  @override
  bool operator ==(Object other) => other is ScopeClosedFailure;

  @override
  int get hashCode => (ScopeClosedFailure).hashCode;
}

/// Anything not anticipated. Logged with its error type; the user sees a
/// calm generic message and nothing is lost.
///
/// Retrying is offered, so every create must reuse the ID generated once for
/// its draft: a retry after an unknown outcome then updates instead of
/// duplicating.
final class UnexpectedFailure extends AppFailure {
  const UnexpectedFailure({super.cause, super.stackTrace});

  @override
  bool get isRetryable => true;

  /// The error's type only: its text may contain user content.
  @override
  String get debugDescription => 'UnexpectedFailure(${cause.runtimeType})';
}
