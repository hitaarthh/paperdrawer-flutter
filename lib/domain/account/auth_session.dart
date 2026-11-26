import 'package:flutter/foundation.dart';

import '../../core/result/result.dart';
import '../plans/plan.dart';
import 'account_scope.dart';

/// A signed-in PaperDrawer account, as the auth service reports it.
///
/// Carries the [scope] that names the account's drawer. The scope is built
/// from a project key the data layer passes in (`DrawerPaths.projectKeyFor`),
/// because the domain can't know backend origins.
///
/// [email] and [displayName] are user content: never log them. [toString]
/// leaves them out.
@immutable
final class AuthSession {
  const AuthSession._({
    required this.scope,
    required this.methods,
    this.email,
    this.displayName,
  });

  /// Builds a session for [userId] in the backend named by [projectKey].
  ///
  /// Fails with `AuthFailure(sessionRejected)` when the ID or key can't be
  /// trusted (see `UserScope.parse`). Blank [email] and [displayName] become
  /// `null`.
  static Result<AuthSession> create({
    required String projectKey,
    required String userId,
    Set<SignInMethod> methods = const {},
    String? email,
    String? displayName,
  }) => UserScope.parse(projectKey: projectKey, userId: userId).map(
    (scope) => AuthSession._(
      scope: scope,
      methods: Set.unmodifiable(methods),
      email: _clean(email),
      displayName: _clean(displayName),
    ),
  );

  final UserScope scope;

  /// The sign-in methods linked to the account (Apple, email).
  final Set<SignInMethod> methods;

  /// The account's email. With Apple's Hide My Email it is a relay address.
  final String? email;

  /// The name to greet the user with. For Apple accounts this is the name
  /// Apple shared on the very first sign-in.
  final String? displayName;

  String get userId => scope.id;

  /// A copy with [name] as the display name.
  AuthSession withDisplayName(String name) => AuthSession._(
    scope: scope,
    methods: methods,
    email: email,
    displayName: _clean(name),
  );

  static String? _clean(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  @override
  bool operator ==(Object other) =>
      other is AuthSession &&
      other.scope == scope &&
      setEquals(other.methods, methods) &&
      other.email == email &&
      other.displayName == displayName;

  @override
  int get hashCode => Object.hash(
    scope,
    Object.hashAllUnordered(methods),
    email,
    displayName,
  );

  /// No email or name: they are user content.
  @override
  String toString() => 'AuthSession($scope)';
}
