import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/failure/app_failure.dart';
import '../../core/failure/failure_mapper.dart';
import '../../core/failure/validation_issue.dart';

/// A content-free stand-in for an auth error, safe to keep as a cause. The
/// SDK's messages can quote the email address.
final class AuthErrorCode {
  const AuthErrorCode(this.code, {this.statusCode});

  final String? code;
  final String? statusCode;

  @override
  String toString() => 'AuthErrorCode($code, $statusCode)';
}

/// Maps Supabase auth errors (GoTrue error codes) to failures.
///
/// - Network errors (`AuthRetryableFetchException`) → [NetworkFailure]: the
///   SDK keeps the session, so being offline never signs anyone out.
/// - Known codes → [AuthFailure] or [ValidationFailure] (table below).
/// - Any other `AuthException` → [UnexpectedFailure] with only its code.
final class SupabaseAuthFailureRule implements FailureRule {
  const SupabaseAuthFailureRule();

  static const _kinds = <String, AuthFailureKind>{
    'invalid_credentials': AuthFailureKind.invalidCredentials,
    'email_not_confirmed': AuthFailureKind.emailNotConfirmed,
    'user_already_exists': AuthFailureKind.emailAlreadyUsed,
    'email_exists': AuthFailureKind.emailAlreadyUsed,
    'identity_already_exists': AuthFailureKind.emailAlreadyUsed,
    'session_not_found': AuthFailureKind.sessionRejected,
    'session_expired': AuthFailureKind.sessionRejected,
    'refresh_token_not_found': AuthFailureKind.sessionRejected,
    'refresh_token_already_used': AuthFailureKind.sessionRejected,
    'bad_jwt': AuthFailureKind.sessionRejected,
    'user_banned': AuthFailureKind.sessionRejected,
    'user_not_found': AuthFailureKind.accountDeleted,
    'over_request_rate_limit': AuthFailureKind.rateLimited,
    'over_email_send_rate_limit': AuthFailureKind.rateLimited,
  };

  static const _issues = <String, ValidationIssue>{
    'weak_password': ValidationIssue.passwordTooShort,
    'email_address_invalid': ValidationIssue.emailInvalid,
  };

  static const _fields = <ValidationIssue, String>{
    ValidationIssue.passwordTooShort: 'password',
    ValidationIssue.emailInvalid: 'email',
  };

  @override
  AppFailure? tryMap(Object error, StackTrace stackTrace) {
    if (error is! AuthException) return null;
    final cause = AuthErrorCode(error.code, statusCode: error.statusCode);
    if (error is AuthRetryableFetchException) {
      return NetworkFailure(cause: cause, stackTrace: stackTrace);
    }
    final issue = error is AuthWeakPasswordException
        ? ValidationIssue.passwordTooShort
        : _issues[error.code];
    if (issue != null) return ValidationFailure(issue, field: _fields[issue]);
    final kind = _kinds[error.code];
    if (kind != null) {
      return AuthFailure(kind, cause: cause, stackTrace: stackTrace);
    }
    return UnexpectedFailure(cause: cause, stackTrace: stackTrace);
  }
}

/// Maps Sign in with Apple errors: closing the sheet is a silent
/// `AuthFailure(cancelled)`; anything else is an [UnexpectedFailure] with
/// only the error code.
final class AppleSignInFailureRule implements FailureRule {
  const AppleSignInFailureRule();

  @override
  AppFailure? tryMap(Object error, StackTrace stackTrace) {
    if (error is SignInWithAppleAuthorizationException) {
      if (error.code == AuthorizationErrorCode.canceled) {
        return AuthFailure(AuthFailureKind.cancelled, stackTrace: stackTrace);
      }
      return UnexpectedFailure(
        cause: AuthErrorCode('apple_${error.code.name}'),
        stackTrace: stackTrace,
      );
    }
    if (error is SignInWithAppleNotSupportedException) {
      return AuthFailure(
        AuthFailureKind.appleUnavailable,
        cause: const AuthErrorCode('apple_not_supported'),
        stackTrace: stackTrace,
      );
    }
    if (error is SignInWithAppleException) {
      return UnexpectedFailure(
        cause: AuthErrorCode('apple_${error.runtimeType}'),
        stackTrace: stackTrace,
      );
    }
    return null;
  }
}
