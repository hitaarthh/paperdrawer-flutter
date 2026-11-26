import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrawer/core/failure/app_failure.dart';
import 'package:paperdrawer/data/drawer/drawer_paths.dart';
import 'package:paperdrawer/domain/account/auth_session.dart';
import 'package:paperdrawer/domain/plans/plan.dart';

/// Domain `AuthSession` tests (kept beside the gateways that build it).
void main() {
  final projectKey = DrawerPaths.projectKeyFor(
    Uri.parse('https://example.supabase.co'),
  );
  const userId = '6F1C2A3B-4D5E-4F60-8A7B-9C0D1E2F3A4B';

  test('builds the drawer scope from the project key and user ID', () {
    final session = AuthSession.create(
      projectKey: projectKey,
      userId: userId,
      methods: {SignInMethod.apple},
    ).requireValue;

    expect(session.scope, DrawerPaths.userScope(
      Uri.parse('https://example.supabase.co'),
      userId,
    ).requireValue);
    expect(session.userId, userId.toLowerCase());
  });

  test('an untrustworthy user ID is a rejected session', () {
    final result = AuthSession.create(projectKey: projectKey, userId: 'a/b');
    expect(
      result.failureOrNull,
      const AuthFailure(AuthFailureKind.sessionRejected),
    );
  });

  test('blank email and name become null', () {
    final session = AuthSession.create(
      projectKey: projectKey,
      userId: userId,
      email: ' ',
      displayName: '',
    ).requireValue;
    expect(session.email, isNull);
    expect(session.displayName, isNull);
  });

  test('toString leaves out the email and name', () {
    final session = AuthSession.create(
      projectKey: projectKey,
      userId: userId,
      email: 'asha@example.com',
      displayName: 'Asha',
    ).requireValue;
    expect(session.toString(), isNot(contains('asha')));
    expect(session.toString(), isNot(contains('Asha')));
  });

  test('value equality includes the linked methods', () {
    AuthSession make(Set<SignInMethod> methods) => AuthSession.create(
      projectKey: projectKey,
      userId: userId,
      methods: methods,
    ).requireValue;
    expect(make({SignInMethod.apple}), make({SignInMethod.apple}));
    expect(make({SignInMethod.apple}), isNot(make({SignInMethod.email})));
    expect(
      make({SignInMethod.apple}).withDisplayName('Asha').displayName,
      'Asha',
    );
  });
}
