import 'dart:convert';

/// Stable numeric IDs for scheduled notifications.
///
/// A notification's identity is its *key*: a string naming the account
/// scope, the kind, the item, the day it fires and its slot on that day
/// (see `PlannedNotification.key`). The same reminder gets the same key, and
/// therefore the same IDs, on every run, so rescheduling replaces instead of
/// duplicating.
///
/// - [stableId]: FNV-1a 64-bit of the key's UTF-8 bytes, truncated to its
///   low 53 bits. It is exact on every Dart platform (web numbers are
///   doubles; 2^53 is the largest exact integer), never negative, and two
///   different keys among a few hundred collide with odds around 10^-11.
///   design-v1 used a 31-bit `hash * 31` (`& 0x7fffffff`), which collides
///   far more often.
/// - [platformId]: the stable ID folded into 1…2^31−1, because
///   `flutter_local_notifications` rejects IDs outside a signed 32-bit int
///   (`validateId`). Collisions within one plan are resolved by the planner
///   (see `ReminderPlanner`).
///
/// The arithmetic uses four 16-bit limbs so every intermediate value stays
/// below 2^53 on the web.
abstract final class NotificationId {
  /// 2^53 − 1.
  static const maxStableId = 0x1FFFFFFFFFFFFF;

  /// 2^31 − 1, the plugin's largest ID.
  static const maxPlatformId = 0x7FFFFFFF;

  static int stableId(String key) {
    // FNV-1a 64 offset basis 0xcbf29ce484222325, low limb first.
    var h0 = 0x2325, h1 = 0x8422, h2 = 0x9ce4, h3 = 0xcbf2;
    for (final byte in utf8.encode(key)) {
      h0 ^= byte;
      // Multiply by the FNV prime 0x100000001b3 = 2^40 + 0x1b3, mod 2^64.
      // Limbs of the prime: [0x01b3, 0x0000, 0x0100, 0x0000].
      final p0 = h0 * 0x1b3;
      final p1 = h1 * 0x1b3 + (p0 >> 16);
      final p2 = h2 * 0x1b3 + h0 * 0x100 + (p1 >> 16);
      final p3 = h3 * 0x1b3 + h1 * 0x100 + (p2 >> 16);
      h0 = p0 & 0xFFFF;
      h1 = p1 & 0xFFFF;
      h2 = p2 & 0xFFFF;
      h3 = p3 & 0xFFFF;
    }
    // Low 53 bits: limbs 0–2 and the low 5 bits of limb 3.
    return (h3 & 0x1F) * 0x1000000000000 + h2 * 0x100000000 + h1 * 0x10000 + h0;
  }

  /// [stableId] folded into 1…[maxPlatformId] (never 0).
  static int platformId(int stableId) {
    final folded = (stableId % maxPlatformId) + 1;
    return folded;
  }
}
