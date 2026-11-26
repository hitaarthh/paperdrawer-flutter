import 'package:flutter/foundation.dart';

import '../../core/failure/app_failure.dart';
import '../../core/result/result.dart';
import 'auth_session.dart';

/// The outcome of creating an account with email and password.
@immutable
sealed class EmailSignUpResult {
  const EmailSignUpResult();
}

/// The account exists and is signed in (email confirmation is off).
final class SignedUpAndSignedIn extends EmailSignUpResult {
  const SignedUpAndSignedIn(this.session);

  final AuthSession session;

  @override
  bool operator ==(Object other) =>
      other is SignedUpAndSignedIn && other.session == session;

  @override
  int get hashCode => session.hashCode;
}

/// A confirmation link was emailed. The user signs in after confirming.
final class ConfirmationSent extends EmailSignUpResult {
  const ConfirmationSent();

  @override
  bool operator ==(Object other) => other is ConfirmationSent;

  @override
  int get hashCode => (ConfirmationSent).hashCode;
}

/// Something that happened to the signed-in account.
@immutable
sealed class AuthEvent {
  const AuthEvent();
}

/// Someone signed in on this phone.
final class AuthSignedIn extends AuthEvent {
  const AuthSignedIn(this.session);

  final AuthSession session;

  @override
  bool operator ==(Object other) =>
      other is AuthSignedIn && other.session == session;

  @override
  int get hashCode => session.hashCode;
}

/// The user signed out. Their drawer stays on the phone.
final class AuthSignedOut extends AuthEvent {
  const AuthSignedOut();

  @override
  bool operator ==(Object other) => other is AuthSignedOut;

  @override
  int get hashCode => (AuthSignedOut).hashCode;
}

/// The server ended the session (password changed, signed out everywhere,
/// account deleted, Apple sign-in disconnected in iOS Settings). The app
/// closes the drawer and shows sign-in; the drawer's file stays on the
/// phone.
final class AuthSessionRejected extends AuthEvent {
  const AuthSessionRejected(this.kind);

  /// `sessionRejected` or `accountDeleted`.
  final AuthFailureKind kind;

  @override
  bool operator ==(Object other) =>
      other is AuthSessionRejected && other.kind == kind;

  @override
  int get hashCode => kind.hashCode;
}

/// Accounts (port): Supabase auth with Sign in with Apple and email.
///
/// Rules every implementation keeps:
/// - Every method returns a [Result] and never throws.
/// - [currentSession] never touches the network, so startup works offline.
/// - Being offline never signs anyone out. Only a server rejection ends a
///   session ([AuthSessionRejected], `AuthFailure(sessionRejected)`).
/// - Nothing here deletes a drawer: closing and keeping files is the app's
///   job, and it always keeps them.
///
/// Common failure cases: `NetworkFailure` (offline, retryable),
/// `AuthFailure(cancelled)` (closed the Apple sheet, silent),
/// `ValidationFailure` (emailInvalid, passwordTooShort, nameRequired),
/// `UnexpectedFailure`.
abstract interface class AuthGateway {
  /// The session saved on this phone, read without the network, or `Ok(null)`
  /// when no one is signed in.
  ///
  /// Failure cases: `AuthFailure(sessionRejected)` when the saved user ID
  /// can't be trusted.
  Future<Result<AuthSession?>> currentSession();

  /// Asks the server whether the saved session still stands (refreshes the
  /// token). `Ok(null)` when no one is signed in.
  ///
  /// Failure cases: `NetworkFailure` (offline: still signed in, nothing
  /// changes), `AuthFailure(sessionRejected | accountDeleted)` (the server
  /// refused: the saved credentials are cleared and [changes] reports
  /// [AuthSessionRejected]).
  Future<Result<AuthSession?>> verifySession();

  /// Sign in with Apple, creating the account on first use. Saves the name
  /// Apple shares only on the very first sign-in.
  ///
  /// Failure cases: `AuthFailure(cancelled)`, `NetworkFailure`,
  /// `UnexpectedFailure` (Apple unavailable, no identity token).
  Future<Result<AuthSession>> signInWithApple();

  /// Failure cases: `ValidationFailure(emailInvalid | passwordTooShort)`,
  /// `AuthFailure(invalidCredentials | emailNotConfirmed)`, `NetworkFailure`.
  Future<Result<AuthSession>> signInWithEmail({
    required String email,
    required String password,
  });

  /// Failure cases: `ValidationFailure(nameRequired | emailInvalid |
  /// passwordTooShort)`, `AuthFailure(emailAlreadyUsed)`, `NetworkFailure`.
  Future<Result<EmailSignUpResult>> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  });

  /// Sends the sign-up confirmation link again.
  ///
  /// Failure cases: `ValidationFailure(emailInvalid)`, `NetworkFailure`.
  Future<Result<Unit>> resendConfirmation(String email);

  /// Clears the saved session on this phone. Works offline. Data stays.
  ///
  /// Failure cases: `UnexpectedFailure` (the Keychain refused); the user is
  /// then still signed in.
  Future<Result<Unit>> signOut();

  /// Deletes the account on the server, including the Apple sign-in link
  /// (App Review requirement).
  ///
  /// Failure cases: `NetworkFailure`, `UnexpectedFailure`.
  Future<Result<Unit>> deleteAccount();

  /// Sign-ins, sign-outs and server rejections, as they happen.
  Stream<AuthEvent> get changes;
}
