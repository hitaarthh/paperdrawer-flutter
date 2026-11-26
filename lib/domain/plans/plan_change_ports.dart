import '../../core/result/result.dart';
import '../account/account_scope.dart';
import '../account/auth_session.dart';
import 'plan.dart';

/// Asks the user to sign in (port; the UI shows the sign-in sheet).
abstract interface class SignInPrompt {
  /// Shows sign-in with only [methods] and returns the signed-in session.
  /// The drawer has switched to the account's drawer when this returns Ok.
  ///
  /// Failure cases: `AuthFailure(cancelled)` (silent), any `AuthGateway`
  /// failure.
  Future<Result<AuthSession>> signIn(Set<SignInMethod> methods);
}

/// What the user chose when asked to move the guest drawer's items.
enum MoveGuestItemsChoice {
  /// The items were copied into the account's drawer (each guest row is
  /// marked as moved; nothing is deleted).
  moved,

  /// The user said no: the items stay in the guest drawer.
  kept,

  /// The guest drawer had nothing to move, so no question was asked.
  nothingToMove,
}

/// Asks "Move these n items into your account?" and, on yes, moves them
/// (port; the UI asks, the data layer copies).
///
/// Contract: moving copies rows and originals into [into]'s drawer and marks
/// the guest rows as moved. It never deletes the guest drawer's rows or
/// files, so a failure halfway loses nothing and can be retried.
abstract interface class MoveGuestItemsPrompt {
  /// Failure cases: `StorageFailure`, `ScopeClosedFailure`.
  Future<Result<MoveGuestItemsChoice>> offer({required UserScope into});
}

/// Starts and stops the plan's sync transport (port over `SyncCoordinator`).
abstract interface class PlanSync {
  /// Drains (push, then pull once more) and stops [kind]'s transport. Ok when
  /// [kind] isn't the one running. Data already in that cloud stays there.
  Future<Result<Unit>> stop(SyncKind kind);

  /// Starts [kind]'s transport for [scope] with a full upload, merged field
  /// by field with whatever the cloud already holds.
  ///
  /// Failure cases: `SyncFailure` (iCloud unavailable, full, mismatch),
  /// `NetworkFailure`, `UnexpectedFailure` (the account's plan doesn't sync
  /// with [kind]).
  Future<Result<Unit>> startWithFullUpload(UserScope scope, SyncKind kind);
}

/// Tells the user, and the website if needed, that the website vault turned
/// read-only after Pro ended (port). The server deletes its copy later,
/// after warnings; nothing on the phone changes.
abstract interface class WebsiteNotifier {
  /// Failure cases: `NetworkFailure`, `UnexpectedFailure`.
  Future<Result<Unit>> websiteBecomesReadOnly(UserScope scope);
}
