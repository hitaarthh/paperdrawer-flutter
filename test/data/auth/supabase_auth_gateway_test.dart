import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrawer/core/failure/app_failure.dart';
import 'package:paperdrawer/core/failure/validation_issue.dart';
import 'package:paperdrawer/core/logging/app_logger.dart';
import 'package:paperdrawer/core/result/result.dart';
import 'package:paperdrawer/data/auth/apple_credentials.dart';
import 'package:paperdrawer/data/auth/apple_nonce.dart';
import 'package:paperdrawer/data/auth/auth_backend.dart';
import 'package:paperdrawer/data/auth/supabase_auth_gateway.dart';
import 'package:paperdrawer/data/drawer/drawer_paths.dart';
import 'package:paperdrawer/domain/account/auth_gateway.dart';
import 'package:paperdrawer/domain/account/auth_session.dart';
import 'package:paperdrawer/domain/plans/plan.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthApiException, AuthRetryableFetchException;

const _userId = '6f1c2a3b-4d5e-4f60-8a7b-9c0d1e2f3a4b';
const _appleSub = '001234.abcdef.1234';
final _projectKey = DrawerPaths.projectKeyFor(
  Uri.parse('https://example.supabase.co'),
);

final class _Backend implements AuthBackend {
  BackendUser? user;
  final List<String> calls = [];
  final StreamController<BackendAuthEvent> controller =
      StreamController<BackendAuthEvent>.broadcast();
  Object? throwOnRefresh;
  Object? throwOnSignIn;
  Object? throwOnSaveName;
  String? lastRawNonce;
  bool signUpNeedsConfirmation = false;

  /// What Supabase holds for the Apple user (name saved earlier, if any).
  String? serverName;

  BackendUser _user({String? email, Set<String> providers = const {'email'}}) =>
      BackendUser(
        id: _userId,
        email: email,
        displayName: serverName,
        providers: providers,
        appleUserId: providers.contains('apple') ? _appleSub : null,
      );

  @override
  BackendUser? get currentUser => user;

  @override
  Future<BackendUser> signInWithPassword(String email, String password) async {
    calls.add('signInWithPassword');
    if (throwOnSignIn case final error?) throw error;
    return user = _user(email: email);
  }

  @override
  Future<BackendUser?> signUp(String name, String email, String password) async {
    calls.add('signUp');
    if (signUpNeedsConfirmation) return null;
    serverName = name;
    return user = _user(email: email);
  }

  @override
  Future<void> resendConfirmation(String email) async =>
      calls.add('resendConfirmation');

  @override
  Future<BackendUser> signInWithAppleIdToken({
    required String idToken,
    required String rawNonce,
  }) async {
    calls.add('signInWithAppleIdToken $idToken');
    lastRawNonce = rawNonce;
    if (throwOnSignIn case final error?) throw error;
    return user = _user(email: 'relay@privaterelay.appleid.com', providers: {'apple'});
  }

  @override
  Future<void> saveDisplayName(String name) async {
    calls.add('saveDisplayName');
    if (throwOnSaveName case final error?) throw error;
    serverName = name;
  }

  @override
  Future<BackendUser> refresh() async {
    calls.add('refresh');
    if (throwOnRefresh case final error?) throw error;
    return user!;
  }

  @override
  Future<void> signOut() async {
    calls.add('signOut');
    user = null;
    controller.add(BackendAuthEvent.signedOut);
  }

  @override
  Stream<BackendAuthEvent> get events => controller.stream;
}

final class _Apple implements AppleCredentialSource {
  final List<String> hashedNonces = [];
  String? givenName;
  String? familyName;
  Object? throwOnRequest;
  AppleCredentialState state = AppleCredentialState.authorized;
  String? identityToken = 'apple-id-token';

  @override
  Future<AppleCredential> request({required String hashedNonce}) async {
    hashedNonces.add(hashedNonce);
    if (throwOnRequest case final error?) throw error;
    return AppleCredential(
      identityToken: identityToken,
      userIdentifier: _appleSub,
      givenName: givenName,
      familyName: familyName,
    );
  }

  @override
  Future<AppleCredentialState> state(String appleUserId) async => state;
}

void main() {
  late _Backend backend;
  late _Apple apple;
  late MemoryLogger logger;
  late SupabaseAuthGateway gateway;
  late List<AuthEvent> events;
  late StreamSubscription<AuthEvent> subscription;

  SupabaseAuthGateway build() => SupabaseAuthGateway(
    backend: backend,
    apple: apple,
    projectKey: _projectKey,
    random: Random(42),
    logger: logger,
    failures: SupabaseAuthGateway.failureMapper(),
  );

  setUp(() {
    backend = _Backend();
    apple = _Apple();
    logger = MemoryLogger();
    gateway = build();
    events = [];
    subscription = gateway.changes.listen(events.add);
  });

  tearDown(() async {
    await subscription.cancel();
    await gateway.dispose();
    await backend.controller.close();
  });

  /// Lets broadcast events reach listeners.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  Future<SupabaseAuthGateway> restoredSession({Set<String> providers = const {'email'}}) async {
    await subscription.cancel();
    await gateway.dispose();
    backend.user = backend._user(email: 'asha@example.com', providers: providers);
    gateway = build();
    subscription = gateway.changes.listen(events.add);
    return gateway;
  }

  group('session restore', () {
    test('no saved session reads as signed out', () async {
      expect(await gateway.currentSession(), const Ok<AuthSession?>(null));
      expect(backend.calls, isEmpty);
    });

    test('the saved session restores offline, without the network', () async {
      await restoredSession();
      final session = (await gateway.currentSession()).requireValue!;
      expect(session.userId, _userId);
      expect(session.scope.projectKey, _projectKey);
      expect(backend.calls, isEmpty);
    });

    test('offline verification keeps the user signed in', () async {
      await restoredSession();
      backend.throwOnRefresh = AuthRetryableFetchException();

      final result = await gateway.verifySession();
      await settle();

      expect(result.failureOrNull, const NetworkFailure());
      expect(backend.calls, ['refresh'], reason: 'no sign-out');
      expect((await gateway.currentSession()).requireValue, isNotNull);
      expect(events, isEmpty);
    });

    test('a server rejection signs out once and reports it', () async {
      await restoredSession();
      backend.throwOnRefresh = AuthApiException(
        'Invalid Refresh Token',
        statusCode: '400',
        code: 'refresh_token_not_found',
      );

      final result = await gateway.verifySession();
      await settle();

      expect(
        result.failureOrNull,
        const AuthFailure(AuthFailureKind.sessionRejected),
      );
      expect(backend.calls, ['refresh', 'signOut']);
      expect(events, [const AuthSessionRejected(AuthFailureKind.sessionRejected)]);
      expect(await gateway.currentSession(), const Ok<AuthSession?>(null));
    });

    test('a deleted account is reported as deleted', () async {
      await restoredSession();
      backend.throwOnRefresh = AuthApiException(
        'User not found',
        statusCode: '404',
        code: 'user_not_found',
      );

      await gateway.verifySession();
      await settle();

      expect(events, [const AuthSessionRejected(AuthFailureKind.accountDeleted)]);
    });

    test('the SDK signing out on its own is a server rejection', () async {
      await restoredSession();
      backend.controller.add(BackendAuthEvent.signedOut);
      await settle();
      backend.controller.add(BackendAuthEvent.signedOut);
      await settle();

      expect(events, [const AuthSessionRejected(AuthFailureKind.sessionRejected)]);
    });

    test('Apple disconnected in iOS Settings ends the session', () async {
      await restoredSession(providers: {'apple'});
      apple.state = AppleCredentialState.revoked;

      final result = await gateway.verifySession();
      await settle();

      expect(
        result.failureOrNull,
        const AuthFailure(AuthFailureKind.sessionRejected),
      );
      expect(backend.calls, ['refresh', 'signOut']);
      expect(events, hasLength(1));
    });

    test('a still-authorized Apple user stays signed in', () async {
      await restoredSession(providers: {'apple'});
      final result = await gateway.verifySession();
      expect(result.requireValue!.methods, {SignInMethod.apple});
    });

    test('a saved user ID that is not a UUID is rejected', () async {
      backend.user = const BackendUser(id: '../other-folder');
      final result = await gateway.currentSession();
      expect(
        result.failureOrNull,
        const AuthFailure(AuthFailureKind.sessionRejected),
      );
    });
  });

  group('Sign in with Apple', () {
    test('sends the nonce hash to Apple and the raw nonce to Supabase',
        () async {
      final result = await gateway.signInWithApple();

      expect(result.isOk, isTrue);
      expect(
        apple.hashedNonces.single,
        AppleNonce.sha256Hex(backend.lastRawNonce!),
      );
      expect(backend.calls.first, 'signInWithAppleIdToken apple-id-token');
    });

    test("saves Apple's name on the first sign-in", () async {
      apple
        ..givenName = 'Asha'
        ..familyName = 'Rao';

      final session = (await gateway.signInWithApple()).requireValue;
      await settle();

      expect(backend.calls, contains('saveDisplayName'));
      expect(backend.serverName, 'Asha Rao');
      expect(session.displayName, 'Asha Rao');
      expect(session.methods, {SignInMethod.apple});
      expect(events, [AuthSignedIn(session)]);
    });

    test('later sign-ins carry no name and keep the saved one', () async {
      backend.serverName = 'Asha Rao';

      final session = (await gateway.signInWithApple()).requireValue;

      expect(backend.calls, isNot(contains('saveDisplayName')));
      expect(session.displayName, 'Asha Rao');
    });

    test("an account that already has a name keeps it", () async {
      backend.serverName = 'Asha';
      apple.givenName = 'A.';

      final session = (await gateway.signInWithApple()).requireValue;

      expect(backend.calls, isNot(contains('saveDisplayName')));
      expect(session.displayName, 'Asha');
    });

    test('a failed name save still signs in and keeps the name', () async {
      apple.givenName = 'Asha';
      backend.throwOnSaveName = AuthRetryableFetchException();

      final session = (await gateway.signInWithApple()).requireValue;

      expect(session.displayName, 'Asha');
      expect(logger.entries.single.$2, contains('saveAppleName'));
      expect(logger.entries.single.$2, isNot(contains('Asha')));
    });

    test('closing the Apple sheet is a silent cancel', () async {
      apple.throwOnRequest = const SignInWithAppleAuthorizationException(
        code: AuthorizationErrorCode.canceled,
        message: 'canceled',
      );

      final result = await gateway.signInWithApple();

      expect(result.failureOrNull, const AuthFailure(AuthFailureKind.cancelled));
      expect(backend.calls, isEmpty);
    });

    test('offline after Apple approves is a network failure', () async {
      backend.throwOnSignIn = AuthRetryableFetchException();
      final result = await gateway.signInWithApple();
      expect(result.failureOrNull, const NetworkFailure());
      expect(events, isEmpty);
    });

    test('no identity token from Apple fails without calling Supabase',
        () async {
      apple.identityToken = null;
      final result = await gateway.signInWithApple();
      expect(result.failureOrNull, isA<UnexpectedFailure>());
      expect(backend.calls, isEmpty);
    });
  });

  group('email', () {
    test('signs in and reports it', () async {
      final result = await gateway.signInWithEmail(
        email: ' asha@example.com ',
        password: 'secret-123',
      );
      await settle();

      expect(result.requireValue.email, 'asha@example.com');
      expect(events.single, isA<AuthSignedIn>());
    });

    test('wrong password is invalid credentials', () async {
      backend.throwOnSignIn = AuthApiException(
        'Invalid login credentials',
        statusCode: '400',
        code: 'invalid_credentials',
      );
      final result = await gateway.signInWithEmail(
        email: 'asha@example.com',
        password: 'nope',
      );
      expect(
        result.failureOrNull,
        const AuthFailure(AuthFailureKind.invalidCredentials),
      );
    });

    test('an unconfirmed email is reported', () async {
      backend.throwOnSignIn = AuthApiException(
        'Email not confirmed',
        statusCode: '400',
        code: 'email_not_confirmed',
      );
      final result = await gateway.signInWithEmail(
        email: 'asha@example.com',
        password: 'secret-123',
      );
      expect(
        result.failureOrNull,
        const AuthFailure(AuthFailureKind.emailNotConfirmed),
      );
    });

    test('rejects a malformed email before calling the server', () async {
      final result = await gateway.signInWithEmail(
        email: 'asha',
        password: 'secret-123',
      );
      expect(
        result.failureOrNull,
        const ValidationFailure(ValidationIssue.emailInvalid, field: 'email'),
      );
      expect(backend.calls, isEmpty);
    });

    test('sign-up checks name and password length first', () async {
      expect(
        (await gateway.signUpWithEmail(
          name: ' ',
          email: 'asha@example.com',
          password: 'secret-123',
        )).failureOrNull,
        const ValidationFailure(ValidationIssue.nameRequired, field: 'name'),
      );
      expect(
        (await gateway.signUpWithEmail(
          name: 'Asha',
          email: 'asha@example.com',
          password: 'short',
        )).failureOrNull,
        const ValidationFailure(
          ValidationIssue.passwordTooShort,
          field: 'password',
        ),
      );
      expect(backend.calls, isEmpty);
    });

    test('sign-up signs in, or asks to confirm the email', () async {
      final signedIn = await gateway.signUpWithEmail(
        name: 'Asha',
        email: 'asha@example.com',
        password: 'secret-123',
      );
      expect(signedIn.requireValue, isA<SignedUpAndSignedIn>());

      backend.signUpNeedsConfirmation = true;
      final confirm = await gateway.signUpWithEmail(
        name: 'Asha',
        email: 'asha@example.com',
        password: 'secret-123',
      );
      expect(confirm.requireValue, const ConfirmationSent());
    });

    test('resends the confirmation link', () async {
      expect(await gateway.resendConfirmation('asha@example.com'), const Ok(unit));
      expect(backend.calls, ['resendConfirmation']);
    });
  });

  test('sign-out works offline and is reported once', () async {
    await restoredSession();
    final result = await gateway.signOut();
    await settle();

    expect(result, const Ok(unit));
    expect(events, [const AuthSignedOut()]);
  });

  test('account deletion fails openly until the server function exists',
      () async {
    final result = await gateway.deleteAccount();
    expect(result.failureOrNull, isA<UnexpectedFailure>());
    expect(
      result.failureOrNull!.cause,
      isA<AccountDeletionUnavailable>(),
    );
  });

  test('logs never contain the email', () async {
    backend.throwOnSignIn = AuthApiException(
      'User asha@example.com already registered',
      statusCode: '422',
      code: 'unexpected_failure',
    );
    await gateway.signInWithEmail(
      email: 'asha@example.com',
      password: 'secret-123',
    );
    expect(logger.entries, isNotEmpty);
    for (final (_, message) in logger.entries) {
      expect(message, isNot(contains('asha')));
    }
  });
}
