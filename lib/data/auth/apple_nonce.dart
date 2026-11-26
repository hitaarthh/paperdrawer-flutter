import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// The nonce for Sign in with Apple through Supabase.
///
/// Apple receives [hashed] (SHA-256, hex) and puts it in the identity token;
/// Supabase receives [raw], hashes it and checks the two match, so a stolen
/// token can't be replayed (standard OpenID Connect nonce handling).
@immutable
final class AppleNonce {
  const AppleNonce._(this.raw, this.hashed);

  /// A fresh nonce of [length] characters from [random] (pass
  /// `Random.secure()` in the app).
  factory AppleNonce.generate(Random random, {int length = 32}) {
    final raw = String.fromCharCodes(
      List.generate(
        length,
        (_) => _charset.codeUnitAt(random.nextInt(_charset.length)),
      ),
    );
    return AppleNonce._(raw, sha256Hex(raw));
  }

  static const _charset =
      '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';

  final String raw;
  final String hashed;

  /// SHA-256 of [value]'s UTF-8 bytes, as lowercase hex.
  static String sha256Hex(String value) =>
      sha256.convert(utf8.encode(value)).toString();
}
