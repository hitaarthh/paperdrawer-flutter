import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrawer/core/failure/app_failure.dart';
import 'package:paperdrawer/core/failure/validation_issue.dart';
import 'package:paperdrawer/data/auth/apple_credentials.dart';
import 'package:paperdrawer/data/auth/apple_nonce.dart';
import 'package:paperdrawer/data/auth/auth_failure_rules.dart';
import 'package:paperdrawer/data/auth/supabase_auth_gateway.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final trace = StackTrace.current;
  final mapper = SupabaseAuthGateway.failureMapper();

  group('SupabaseAuthFailureRule', () {
    AppFailure code(String value, {String status = '400'}) => mapper.map(
      AuthApiException('message with someone@example.com', statusCode: status, code: value),
      trace,
    );

    test('maps sign-in and sign-up codes', () {
      expect(
        code('invalid_credentials'),
        const AuthFailure(AuthFailureKind.invalidCredentials),
      );
      expect(
        code('email_not_confirmed'),
        const AuthFailure(AuthFailureKind.emailNotConfirmed),
      );
      for (final value in ['user_already_exists', 'email_exists']) {
        expect(code(value), const AuthFailure(AuthFailureKind.emailAlreadyUsed));
      }
    });

    test('server rejections of the session are sessionRejected', () {
      for (final value in [
        'refresh_token_not_found',
        'refresh_token_already_used',
        'session_not_found',
        'session_expired',
        'bad_jwt',
        'user_banned',
      ]) {
        expect(
          code(value, status: '401'),
          const AuthFailure(AuthFailureKind.sessionRejected),
          reason: value,
        );
      }
      expect(
        code('user_not_found', status: '404'),
        const AuthFailure(AuthFailureKind.accountDeleted),
      );
    });

    test('weak passwords and bad emails are validation failures', () {
      expect(
        code('weak_password'),
        const ValidationFailure(ValidationIssue.passwordTooShort, field: 'password'),
      );
      expect(
        code('email_address_invalid'),
        const ValidationFailure(ValidationIssue.emailInvalid, field: 'email'),
      );
    });

    test('a network error is a network failure, never a rejection', () {
      expect(
        mapper.map(AuthRetryableFetchException(), trace),
        const NetworkFailure(),
      );
    });

    test('rate limits ask the user to wait', () {
      expect(
        code('over_request_rate_limit', status: '429'),
        const AuthFailure(AuthFailureKind.rateLimited),
      );
    });

    test('unknown codes are unexpected and keep only the code', () {
      final failure = code('some_future_code', status: '400');
      expect(failure, isA<UnexpectedFailure>());
      expect(failure.cause, isA<AuthErrorCode>());
      expect(failure.cause.toString(), isNot(contains('@')));
    });
  });

  group('AppleSignInFailureRule', () {
    test('closing the Apple sheet is a silent cancel', () {
      final failure = mapper.map(
        const SignInWithAppleAuthorizationException(
          code: AuthorizationErrorCode.canceled,
          message: 'The user canceled',
        ),
        trace,
      );
      expect(failure, const AuthFailure(AuthFailureKind.cancelled));
      expect(failure.isSilent, isTrue);
    });

    test('other Apple errors are unexpected', () {
      final failure = mapper.map(
        const SignInWithAppleAuthorizationException(
          code: AuthorizationErrorCode.failed,
          message: 'failed',
        ),
        trace,
      );
      expect(failure, isA<UnexpectedFailure>());
    });
  });

  group('AppleNonce', () {
    test('SHA-256 matches the standard test vector', () {
      expect(
        AppleNonce.sha256Hex('abc'),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
    });

    test('Apple gets the hash of the raw nonce Supabase gets', () {
      final nonce = AppleNonce.generate(Random(7));
      expect(nonce.raw, hasLength(32));
      expect(nonce.hashed, AppleNonce.sha256Hex(nonce.raw));
      expect(nonce.hashed, isNot(nonce.raw));
    });

    test('each nonce is fresh', () {
      final random = Random(7);
      expect(
        AppleNonce.generate(random).raw,
        isNot(AppleNonce.generate(random).raw),
      );
    });
  });

  group('AppleCredential', () {
    test('joins the name Apple shared', () {
      expect(
        const AppleCredential(
          identityToken: 't',
          userIdentifier: 'u',
          givenName: 'Asha',
          familyName: ' Rao ',
        ).fullName,
        'Asha Rao',
      );
    });

    test('no name after the first sign-in', () {
      expect(
        const AppleCredential(identityToken: 't', userIdentifier: 'u').fullName,
        isNull,
      );
      expect(
        const AppleCredential(
          identityToken: 't',
          userIdentifier: 'u',
          givenName: ' ',
        ).fullName,
        isNull,
      );
    });
  });
}
