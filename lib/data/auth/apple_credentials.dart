import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// What Apple returned from the Sign in with Apple sheet. User content:
/// never log it.
@immutable
final class AppleCredential {
  const AppleCredential({
    required this.identityToken,
    required this.userIdentifier,
    this.givenName,
    this.familyName,
  });

  final String? identityToken;
  final String? userIdentifier;

  /// Apple shares the name on the very first sign-in only.
  final String? givenName;
  final String? familyName;

  /// "Given Family", or `null` when Apple shared no name.
  String? get fullName {
    final parts = [givenName, familyName]
        .map((part) => part?.trim() ?? '')
        .where((part) => part.isNotEmpty);
    return parts.isEmpty ? null : parts.join(' ');
  }
}

/// Whether Apple still authorizes the app for an Apple user.
enum AppleCredentialState { authorized, revoked, notFound }

/// The Sign in with Apple sheet (port). Throws the plugin's errors;
/// `AppleSignInFailureRule` maps them.
abstract interface class AppleCredentialSource {
  /// Shows the sheet, asking for the name and email, with [hashedNonce]
  /// (SHA-256 hex of the raw nonce later given to Supabase).
  Future<AppleCredential> request({required String hashedNonce});

  /// Whether the user disconnected PaperDrawer from their Apple ID in iOS
  /// Settings.
  Future<AppleCredentialState> state(String appleUserId);
}

/// [AppleCredentialSource] over the `sign_in_with_apple` plugin (native
/// AuthenticationServices on iOS and macOS).
final class NativeAppleCredentialSource implements AppleCredentialSource {
  const NativeAppleCredentialSource();

  @override
  Future<AppleCredential> request({required String hashedNonce}) async {
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );
    return AppleCredential(
      identityToken: credential.identityToken,
      userIdentifier: credential.userIdentifier,
      givenName: credential.givenName,
      familyName: credential.familyName,
    );
  }

  @override
  Future<AppleCredentialState> state(String appleUserId) async {
    final state = await SignInWithApple.getCredentialState(appleUserId);
    return switch (state) {
      CredentialState.authorized => AppleCredentialState.authorized,
      CredentialState.revoked => AppleCredentialState.revoked,
      CredentialState.notFound => AppleCredentialState.notFound,
    };
  }
}
