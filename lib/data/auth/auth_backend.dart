import 'package:flutter/foundation.dart';

/// A Supabase user, reduced to what the app needs. User content: never log
/// [email] or [displayName].
@immutable
final class BackendUser {
  const BackendUser({
    required this.id,
    this.email,
    this.displayName,
    this.providers = const {},
    this.appleUserId,
  });

  final String id;
  final String? email;

  /// `user_metadata.name` (design-v1's sign-up writes it).
  final String? displayName;

  /// Linked identity providers, as Supabase names them (`email`, `apple`).
  final Set<String> providers;

  /// Apple's user identifier (`sub`) when an Apple identity is linked.
  final String? appleUserId;
}

/// What the auth client reported.
enum BackendAuthEvent {
  signedIn,

  /// The session is gone: our own sign-out, or the server rejected the
  /// refresh token (the SDK signs out only then, never for a network error).
  signedOut,

  /// Token refreshes, user updates and the like.
  other,
}

/// The Supabase auth calls PaperDrawer makes (port), so the gateway's rules
/// can be tested without the network. `SharedAccountAuthBackend` implements
/// it over design-v1's `SharedAccount`.
///
/// Methods throw the SDK's errors (`AuthException` and subclasses); the
/// gateway maps them.
abstract interface class AuthBackend {
  /// The user of the session restored from the Keychain. No network.
  BackendUser? get currentUser;

  Future<BackendUser> signInWithPassword(String email, String password);

  /// Returns the signed-in user, or `null` when a confirmation link was sent.
  Future<BackendUser?> signUp(String name, String email, String password);

  Future<void> resendConfirmation(String email);

  /// Signs in with an Apple identity token; [rawNonce] is the unhashed nonce
  /// whose SHA-256 was given to Apple.
  Future<BackendUser> signInWithAppleIdToken({
    required String idToken,
    required String rawNonce,
  });

  /// Saves [name] as the account's display name (`user_metadata.name`).
  Future<void> saveDisplayName(String name);

  /// Refreshes the session with the server.
  Future<BackendUser> refresh();

  /// Clears the saved session on this phone; works offline.
  Future<void> signOut();

  Stream<BackendAuthEvent> get events;
}
