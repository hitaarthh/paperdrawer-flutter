import 'dart:async';
import 'dart:math';

import '../../core/failure/app_failure.dart';
import '../../core/failure/failure_mapper.dart';
import '../../core/failure/validation_issue.dart';
import '../../core/logging/app_logger.dart';
import '../../core/result/result.dart';
import '../../domain/account/auth_gateway.dart';
import '../../domain/account/auth_session.dart';
import '../../domain/plans/plan.dart';
import '../errors/network_failure_rule.dart';
import 'apple_credentials.dart';
import 'apple_nonce.dart';
import 'auth_backend.dart';
import 'auth_failure_rules.dart';

/// [AuthGateway] over Supabase auth (design-v1's `SharedAccount` through
/// [AuthBackend]) plus Sign in with Apple.
///
/// Session rules:
/// - [currentSession] reads the Keychain-restored session; no network.
/// - Offline never signs out: a network error leaves the session as it is.
/// - A server rejection (refresh refused, Apple sign-in revoked in iOS
///   Settings, the SDK signing out on its own) clears the saved credentials
///   and reports [AuthSessionRejected] once. The drawer file stays.
///
/// Build the mapper with [failureMapper].
final class SupabaseAuthGateway implements AuthGateway {
  SupabaseAuthGateway({
    required AuthBackend backend,
    required AppleCredentialSource apple,
    required String projectKey,
    required Random random,
    required AppLogger logger,
    required FailureMapper failures,
  }) : _backend = backend,
       _apple = apple,
       _projectKey = projectKey,
       _random = random,
       _logger = logger,
       _failures = failures {
    _activeUserId = backend.currentUser?.id;
    _subscription = backend.events.listen(_onBackendEvent);
  }

  /// The mapper this gateway expects: Apple, Supabase auth, then network.
  static FailureMapper failureMapper() => FailureMapper(
    extraRules: const [
      AppleSignInFailureRule(),
      SupabaseAuthFailureRule(),
      NetworkFailureRule(),
    ],
  );

  /// design-v1's minimum for new passwords (account_screen.dart).
  static const minPasswordLength = 8;

  final AuthBackend _backend;
  final AppleCredentialSource _apple;
  final String _projectKey;
  final Random _random;
  final AppLogger _logger;
  final FailureMapper _failures;
  final StreamController<AuthEvent> _events =
      StreamController<AuthEvent>.broadcast();
  late final StreamSubscription<BackendAuthEvent> _subscription;

  /// Who this gateway last reported as signed in; `null` when signed out.
  /// Every event is emitted on a change of this value, so nothing is
  /// reported twice.
  String? _activeUserId;

  @override
  Stream<AuthEvent> get changes => _events.stream;

  @override
  Future<Result<AuthSession?>> currentSession() async {
    try {
      final user = _backend.currentUser;
      if (user == null) return const Ok(null);
      return _session(user);
    } catch (error, stackTrace) {
      return _fail<AuthSession?>('currentSession', error, stackTrace);
    }
  }

  @override
  Future<Result<AuthSession?>> verifySession() async {
    if (_backend.currentUser == null) return const Ok(null);
    final BackendUser user;
    try {
      user = await _backend.refresh();
    } catch (error, stackTrace) {
      final failure = _failures.map(error, stackTrace);
      _logger.failure('SupabaseAuthGateway.verifySession', failure);
      if (failure case AuthFailure(:final kind)
          when _endsSession(kind)) {
        await _endSession(kind);
      }
      return Err<AuthSession?>(failure);
    }
    if (await _appleRevoked(user)) {
      await _endSession(AuthFailureKind.sessionRejected);
      return const Err<AuthSession?>(
        AuthFailure(AuthFailureKind.sessionRejected),
      );
    }
    return _session(user);
  }

  @override
  Future<Result<AuthSession>> signInWithApple() async {
    try {
      final nonce = AppleNonce.generate(_random);
      final credential = await _apple.request(hashedNonce: nonce.hashed);
      final token = credential.identityToken;
      if (token == null || token.isEmpty) {
        throw StateError('Apple returned no identity token');
      }
      final user = await _backend.signInWithAppleIdToken(
        idToken: token,
        rawNonce: nonce.raw,
      );
      return _signedIn(await _withAppleName(user, credential.fullName));
    } catch (error, stackTrace) {
      return _fail<AuthSession>('signInWithApple', error, stackTrace);
    }
  }

  @override
  Future<Result<AuthSession>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final invalid =
        _checkEmail(email) ??
        (password.isEmpty ? _passwordInvalid : null);
    if (invalid != null) return Err<AuthSession>(invalid);
    try {
      final user = await _backend.signInWithPassword(email.trim(), password);
      return _signedIn(user);
    } catch (error, stackTrace) {
      return _fail<AuthSession>('signInWithEmail', error, stackTrace);
    }
  }

  @override
  Future<Result<EmailSignUpResult>> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    final invalid =
        (name.trim().isEmpty ? _nameMissing : null) ??
        _checkEmail(email) ??
        (password.length < minPasswordLength ? _passwordInvalid : null);
    if (invalid != null) return Err<EmailSignUpResult>(invalid);
    try {
      final user = await _backend.signUp(name.trim(), email.trim(), password);
      if (user == null) return const Ok(ConfirmationSent());
      return _signedIn(user).map<EmailSignUpResult>(SignedUpAndSignedIn.new);
    } catch (error, stackTrace) {
      return _fail<EmailSignUpResult>('signUpWithEmail', error, stackTrace);
    }
  }

  @override
  Future<Result<Unit>> resendConfirmation(String email) async {
    final invalid = _checkEmail(email);
    if (invalid != null) return Err<Unit>(invalid);
    try {
      await _backend.resendConfirmation(email.trim());
      return const Ok(unit);
    } catch (error, stackTrace) {
      return _fail<Unit>('resendConfirmation', error, stackTrace);
    }
  }

  @override
  Future<Result<Unit>> signOut() async {
    final previous = _activeUserId;
    // Cleared first, so the SDK's own signed-out event isn't read as a
    // server rejection.
    _activeUserId = null;
    try {
      await _backend.signOut();
    } catch (error, stackTrace) {
      _activeUserId = previous;
      return _fail<Unit>('signOut', error, stackTrace);
    }
    if (previous != null) _events.add(const AuthSignedOut());
    return const Ok(unit);
  }

  /// TODO(server): account deletion needs a server function (an Edge
  /// Function with the service role) that deletes the user's rows, storage
  /// files and RevenueCat customer, and revokes the Apple sign-in with
  /// Apple's REST API (App Review requirement). None exists yet, so this
  /// reports a failure instead of pretending to succeed.
  @override
  Future<Result<Unit>> deleteAccount() async {
    const failure = UnexpectedFailure(cause: AccountDeletionUnavailable());
    _logger.failure('SupabaseAuthGateway.deleteAccount', failure);
    return const Err<Unit>(failure);
  }

  Future<void> dispose() async {
    await _subscription.cancel();
    await _events.close();
  }

  void _onBackendEvent(BackendAuthEvent event) {
    switch (event) {
      case BackendAuthEvent.signedOut:
        // Our own sign-outs clear [_activeUserId] first, so a sign-out while
        // someone is still active came from the server.
        if (_activeUserId == null) return;
        _activeUserId = null;
        _logger.warning('Session ended by the server');
        _events.add(const AuthSessionRejected(AuthFailureKind.sessionRejected));
      case BackendAuthEvent.signedIn || BackendAuthEvent.other:
        // Sign-ins are reported by the method that made them.
        return;
    }
  }

  static bool _endsSession(AuthFailureKind kind) => switch (kind) {
    AuthFailureKind.sessionRejected || AuthFailureKind.accountDeleted => true,
    AuthFailureKind.cancelled ||
    AuthFailureKind.invalidCredentials ||
    AuthFailureKind.emailAlreadyUsed ||
    AuthFailureKind.emailNotConfirmed => false,
  };

  /// Clears the dead credentials and reports the rejection once.
  Future<void> _endSession(AuthFailureKind kind) async {
    final wasActive = _activeUserId != null;
    _activeUserId = null;
    if (wasActive) _events.add(AuthSessionRejected(kind));
    try {
      await _backend.signOut();
    } catch (error, stackTrace) {
      _logger.failure(
        'SupabaseAuthGateway clearing a rejected session',
        _failures.map(error, stackTrace),
      );
    }
  }

  /// True when the user disconnected PaperDrawer from their Apple ID. An
  /// error checking (simulator, no Apple ID) is not a rejection.
  Future<bool> _appleRevoked(BackendUser user) async {
    final appleUserId = user.appleUserId;
    if (appleUserId == null) return false;
    try {
      final state = await _apple.state(appleUserId);
      return switch (state) {
        AppleCredentialState.revoked => true,
        AppleCredentialState.authorized || AppleCredentialState.notFound =>
          false,
      };
    } catch (error, stackTrace) {
      _logger.failure(
        'SupabaseAuthGateway.appleState',
        _failures.map(error, stackTrace),
      );
      return false;
    }
  }

  /// Apple shares the name only on the very first sign-in: save it then,
  /// unless the account already has a name (an email account linking
  /// Apple). If saving fails, the session still carries the name so the
  /// app's settings sync can keep it.
  Future<BackendUser> _withAppleName(BackendUser user, String? name) async {
    final hasName = user.displayName?.trim().isNotEmpty ?? false;
    if (name == null || hasName) return user;
    try {
      await _backend.saveDisplayName(name);
    } catch (error, stackTrace) {
      _logger.failure(
        'SupabaseAuthGateway.saveAppleName',
        _failures.map(error, stackTrace),
      );
    }
    return BackendUser(
      id: user.id,
      email: user.email,
      displayName: name,
      providers: user.providers,
      appleUserId: user.appleUserId,
    );
  }

  Result<AuthSession> _signedIn(BackendUser user) {
    final session = _session(user);
    if (session case Ok(:final value)) {
      _activeUserId = value.userId;
      _events.add(AuthSignedIn(value));
    }
    return session;
  }

  Result<AuthSession> _session(BackendUser user) => AuthSession.create(
    projectKey: _projectKey,
    userId: user.id,
    email: user.email,
    displayName: user.displayName,
    methods: {
      for (final provider in user.providers) ?_methodFor(provider),
    },
  );

  /// Supabase provider names; others (phone, SSO) aren't offered.
  static SignInMethod? _methodFor(String provider) => switch (provider) {
    'apple' => SignInMethod.apple,
    'email' => SignInMethod.email,
    'google' => SignInMethod.google,
    _ => null,
  };

  static ValidationFailure? _checkEmail(String email) =>
      _emailPattern.hasMatch(email.trim())
      ? null
      : const ValidationFailure(ValidationIssue.emailInvalid, field: 'email');

  static const _passwordInvalid = ValidationFailure(
    ValidationIssue.passwordTooShort,
    field: 'password',
  );

  static const _nameMissing = ValidationFailure(
    ValidationIssue.nameRequired,
    field: 'name',
  );

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  Err<T> _fail<T>(String where, Object error, StackTrace stackTrace) {
    final failure = _failures.map(error, stackTrace);
    _logger.failure('SupabaseAuthGateway.$where', failure);
    return Err<T>(failure);
  }
}

/// Cause of [SupabaseAuthGateway.deleteAccount]'s failure until the server
/// function exists.
final class AccountDeletionUnavailable {
  const AccountDeletionUnavailable();

  @override
  String toString() => 'AccountDeletionUnavailable';
}
