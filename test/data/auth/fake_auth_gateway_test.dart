import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrawer/core/failure/app_failure.dart';
import 'package:paperdrawer/core/id/id_generator.dart';
import 'package:paperdrawer/core/result/result.dart';
import 'package:paperdrawer/data/auth/fake_auth_gateway.dart';
import 'package:paperdrawer/domain/account/auth_gateway.dart';
import 'package:paperdrawer/domain/account/auth_session.dart';
import 'package:paperdrawer/domain/plans/plan.dart';

const _projectKey = 'aHR0cHM6Ly9leGFtcGxlLnN1cGFiYXNlLmNv';

/// UUID-shaped, predictable IDs (sessions require UUIDs).
final class _UuidSequence implements IdGenerator {
  int _count = 0;

  @override
  String next() =>
      '00000000-0000-4000-8000-${(++_count).toString().padLeft(12, '0')}';
}

void main() {
  late FakeAuthGateway auth;
  late List<AuthEvent> events;
  late StreamSubscription<AuthEvent> subscription;

  setUp(() {
    auth = FakeAuthGateway(projectKey: _projectKey, ids: _UuidSequence());
    events = [];
    subscription = auth.changes.listen(events.add);
  });

  tearDown(() async {
    await subscription.cancel();
    await auth.dispose();
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('Apple shares the name only the first time; the account keeps it',
      () async {
    auth.nextAppleUser = (appleUserId: 'apple-1', name: 'Asha Rao');
    final first = (await auth.signInWithApple()).requireValue;
    await auth.signOut();

    auth.nextAppleUser = (appleUserId: 'apple-1', name: null);
    final second = (await auth.signInWithApple()).requireValue;

    expect(first.displayName, 'Asha Rao');
    expect(second.displayName, 'Asha Rao');
    expect(second.scope, first.scope, reason: 'same account, same drawer');
    expect(second.methods, {SignInMethod.apple});
  });

  test('no Apple user scripted reads as a cancelled sheet', () async {
    final result = await auth.signInWithApple();
    expect(result.failureOrNull, const AuthFailure(AuthFailureKind.cancelled));
  });

  test('offline: sign-in fails, the saved session stays', () async {
    await auth.signUpWithEmail(
      name: 'Asha',
      email: 'asha@example.com',
      password: 'secret-123',
    );
    auth.offline = true;

    expect((await auth.verifySession()).failureOrNull, const NetworkFailure());
    expect((await auth.currentSession()).requireValue, isNotNull);
    expect(
      (await auth.signInWithEmail(email: 'x@example.com', password: 'x'))
          .failureOrNull,
      const NetworkFailure(),
    );
  });

  test('a server rejection is reported once and signs out', () async {
    auth.nextAppleUser = (appleUserId: 'apple-1', name: null);
    await auth.signInWithApple();
    auth
      ..rejectSession()
      ..rejectSession();
    await settle();

    expect(events.whereType<AuthSessionRejected>(), hasLength(1));
    expect(await auth.currentSession(), const Ok<AuthSession?>(null));
  });

  test('email sign-up with confirmation, then sign-in after confirming',
      () async {
    auth.requireEmailConfirmation = true;
    final signUp = await auth.signUpWithEmail(
      name: 'Asha',
      email: 'asha@example.com',
      password: 'secret-123',
    );
    expect(signUp.requireValue, const ConfirmationSent());

    final early = await auth.signInWithEmail(
      email: 'asha@example.com',
      password: 'secret-123',
    );
    expect(
      early.failureOrNull,
      const AuthFailure(AuthFailureKind.emailNotConfirmed),
    );

    auth.accounts.values.single.confirmed = true;
    final signedIn = await auth.signInWithEmail(
      email: 'asha@example.com',
      password: 'secret-123',
    );
    expect(signedIn.requireValue.methods, {SignInMethod.email});
  });

  test('the same email cannot make a second account', () async {
    await auth.signUpWithEmail(
      name: 'Asha',
      email: 'asha@example.com',
      password: 'secret-123',
    );
    final again = await auth.signUpWithEmail(
      name: 'Asha',
      email: 'ASHA@example.com',
      password: 'secret-456',
    );
    expect(
      again.failureOrNull,
      const AuthFailure(AuthFailureKind.emailAlreadyUsed),
    );
  });

  test('account deletion is not built and says so', () async {
    expect((await auth.deleteAccount()).failureOrNull, isA<UnexpectedFailure>());
  });
}
