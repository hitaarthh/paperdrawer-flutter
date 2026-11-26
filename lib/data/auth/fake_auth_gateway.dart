import 'dart:async';

import '../../core/failure/app_failure.dart';
import '../../core/failure/validation_issue.dart';
import '../../core/id/id_generator.dart';
import '../../core/result/result.dart';
import '../../domain/account/auth_gateway.dart';
import '../../domain/account/auth_session.dart';
import '../../domain/plans/plan.dart';

/// One account known to [FakeAuthGateway].
final class FakeAccount {
  FakeAccount({required this.userId, this.email, this.password, this.name});

  final String userId;
  final String? email;
  final String? password;
  String? name;
  bool confirmed = true;
  final Set<SignInMethod> methods = {};
}

/// [AuthGateway] in memory, for tests and the simulator. No network.
///
/// [ids] must produce UUIDs (`UuidGenerator`), because sessions build a
/// `UserScope`. Script Apple's sheet with [nextAppleUser]; inject failures
/// with [failNextWith]; go [offline]; end the session from the "server"
/// with [rejectSession].
final class FakeAuthGateway implements AuthGateway {
  FakeAuthGateway({
    required String projectKey,
    required IdGenerator ids,
    this.requireEmailConfirmation = false,
  }) : _projectKey = projectKey,
       _ids = ids;

  final String _projectKey;
  final IdGenerator _ids;
  final StreamController<AuthEvent> _events =
      StreamController<AuthEvent>.broadcast();

  /// Accounts by user ID.
  final Map<String, FakeAccount> accounts = {};
  final Map<String, String> _appleUsers = {};

  /// When true, sign-up sends a confirmation link instead of signing in.
  bool requireEmailConfirmation;

  /// The Apple ID the next Apple sheet signs in with: its Apple user ID and
  /// the name Apple shares (only on that Apple ID's first sign-in).
  ({String appleUserId, String? name})? nextAppleUser;

  /// The next call that needs the server fails with this, once.
  AppFailure? failNextWith;

  /// No network: server calls fail with `NetworkFailure`; the saved session
  /// stays.
  bool offline = false;

  FakeAccount? _signedIn;

  @override
  Stream<AuthEvent> get changes => _events.stream;

  @override
  Future<Result<AuthSession?>> currentSession() async {
    final account = _signedIn;
    if (account == null) return const Ok(null);
    return _session(account);
  }

  @override
  Future<Result<AuthSession?>> verifySession() async {
    final account = _signedIn;
    if (account == null) return const Ok(null);
    final failure = _serverFailure();
    if (failure != null) return Err<AuthSession?>(failure);
    return _session(account);
  }

  @override
  Future<Result<AuthSession>> signInWithApple() async {
    final failure = _serverFailure();
    if (failure != null) return Err<AuthSession>(failure);
    final apple = nextAppleUser;
    if (apple == null) {
      return const Err<AuthSession>(AuthFailure(AuthFailureKind.cancelled));
    }
    nextAppleUser = null;
    final known = _appleUsers[apple.appleUserId];
    final account = known == null
        ? FakeAccount(userId: _ids.next(), name: apple.name)
        : accounts[known]!;
    accounts[account.userId] = account;
    _appleUsers[apple.appleUserId] = account.userId;
    account.methods.add(SignInMethod.apple);
    return _signIn(account);
  }

  @override
  Future<Result<AuthSession>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final failure = _serverFailure();
    if (failure != null) return Err<AuthSession>(failure);
    final account = _byEmail(email);
    if (account == null || account.password != password) {
      return const Err<AuthSession>(
        AuthFailure(AuthFailureKind.invalidCredentials),
      );
    }
    if (!account.confirmed) {
      return const Err<AuthSession>(
        AuthFailure(AuthFailureKind.emailNotConfirmed),
      );
    }
    return _signIn(account);
  }

  @override
  Future<Result<EmailSignUpResult>> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    if (password.length < 8) {
      return const Err<EmailSignUpResult>(
        ValidationFailure(ValidationIssue.passwordTooShort, field: 'password'),
      );
    }
    final failure = _serverFailure();
    if (failure != null) return Err<EmailSignUpResult>(failure);
    if (_byEmail(email) != null) {
      return const Err<EmailSignUpResult>(
        AuthFailure(AuthFailureKind.emailAlreadyUsed),
      );
    }
    final account = FakeAccount(
      userId: _ids.next(),
      email: email.trim(),
      password: password,
      name: name.trim(),
    )..methods.add(SignInMethod.email);
    accounts[account.userId] = account;
    if (requireEmailConfirmation) {
      account.confirmed = false;
      return const Ok(ConfirmationSent());
    }
    return _signIn(account).map<EmailSignUpResult>(SignedUpAndSignedIn.new);
  }

  @override
  Future<Result<Unit>> resendConfirmation(String email) async {
    final failure = _serverFailure();
    return failure == null ? const Ok(unit) : Err<Unit>(failure);
  }

  @override
  Future<Result<Unit>> signOut() async {
    if (_signedIn == null) return const Ok(unit);
    _signedIn = null;
    _events.add(const AuthSignedOut());
    return const Ok(unit);
  }

  @override
  Future<Result<Unit>> deleteAccount() async => const Err<Unit>(
    UnexpectedFailure(cause: 'account deletion is not built'),
  );

  /// The server ended the session (password changed elsewhere, Apple
  /// disconnected): reported once, and the next [verifySession] fails.
  void rejectSession({AuthFailureKind kind = AuthFailureKind.sessionRejected}) {
    if (_signedIn == null) return;
    _signedIn = null;
    _events.add(AuthSessionRejected(kind));
  }

  Future<void> dispose() => _events.close();

  Result<AuthSession> _signIn(FakeAccount account) {
    final session = _session(account);
    if (session case Ok(:final value)) {
      _signedIn = account;
      _events.add(AuthSignedIn(value));
    }
    return session;
  }

  Result<AuthSession> _session(FakeAccount account) => AuthSession.create(
    projectKey: _projectKey,
    userId: account.userId,
    methods: account.methods,
    email: account.email,
    displayName: account.name,
  );

  FakeAccount? _byEmail(String email) {
    final wanted = email.trim().toLowerCase();
    for (final account in accounts.values) {
      if (account.email?.toLowerCase() == wanted) return account;
    }
    return null;
  }

  AppFailure? _serverFailure() {
    if (offline) return const NetworkFailure();
    final failure = failNextWith;
    failNextWith = null;
    return failure;
  }
}
