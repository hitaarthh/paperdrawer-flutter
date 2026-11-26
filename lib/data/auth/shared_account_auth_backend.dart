import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/shared_account.dart';
import 'auth_backend.dart';

/// [AuthBackend] over design-v1's [SharedAccount], which keeps the session
/// in the iOS Keychain. Email sign-in, sign-up, resend and sign-out go
/// through [SharedAccount] unchanged; Apple sign-in, name saving and refresh
/// use its Supabase client.
///
/// Known gap: `SharedAccount` re-enables Keychain persistence only in its own
/// `signIn`/`signUp`. After a sign-out in the same app run, an Apple sign-in
/// works but isn't saved to the Keychain until the next email sign-in, so
/// the next launch opens signed out (the drawer stays on disk). Fix needs a
/// `SharedAccount.signInWithIdToken` that calls `allowPersistence()` first.
final class SharedAccountAuthBackend implements AuthBackend {
  SharedAccountAuthBackend(this._account);

  final SharedAccount _account;

  GoTrueClient get _auth => _account.client.auth;

  @override
  BackendUser? get currentUser => _user(_auth.currentUser);

  @override
  Future<BackendUser> signInWithPassword(String email, String password) async {
    await _account.signIn(email, password);
    return _requireUser(_auth.currentUser);
  }

  @override
  Future<BackendUser?> signUp(String name, String email, String password) async {
    final signedIn = await _account.signUp(name, email, password);
    return signedIn ? _requireUser(_auth.currentUser) : null;
  }

  @override
  Future<void> resendConfirmation(String email) =>
      _account.resendConfirmation(email);

  @override
  Future<BackendUser> signInWithAppleIdToken({
    required String idToken,
    required String rawNonce,
  }) async {
    final response = await _auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
      nonce: rawNonce,
    );
    return _requireUser(response.user);
  }

  @override
  Future<void> saveDisplayName(String name) async {
    await _auth.updateUser(UserAttributes(data: {'name': name}));
  }

  @override
  Future<BackendUser> refresh() async {
    final response = await _auth.refreshSession();
    return _requireUser(response.user ?? _auth.currentUser);
  }

  @override
  Future<void> signOut() => _account.signOut();

  @override
  Stream<BackendAuthEvent> get events => _account.changes.map(
    (state) => state.event == AuthChangeEvent.signedIn
        ? BackendAuthEvent.signedIn
        : state.event == AuthChangeEvent.signedOut
        ? BackendAuthEvent.signedOut
        : BackendAuthEvent.other,
  );

  static BackendUser _requireUser(User? user) =>
      _user(user) ?? (throw StateError('auth response without a user'));

  static BackendUser? _user(User? user) {
    if (user == null) return null;
    final identities = user.identities ?? const <UserIdentity>[];
    String? appleUserId;
    for (final identity in identities) {
      if (identity.provider != 'apple') continue;
      final sub = identity.identityData?['sub'];
      appleUserId = sub is String ? sub : identity.id;
    }
    final name = user.userMetadata?['name'];
    return BackendUser(
      id: user.id,
      email: user.email,
      displayName: name is String ? name : null,
      providers: {for (final identity in identities) identity.provider},
      appleUserId: appleUserId,
    );
  }
}
