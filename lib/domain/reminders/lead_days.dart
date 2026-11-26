import 'notification_kind.dart';

/// [leadDays] as stored and compared: unique, furthest first (`[30, 7, 0]`).
///
/// Returns `null` when any value is not one of
/// `NotificationKind.leadDayChoices`.
List<int>? normaliseLeadDays(Iterable<int> leadDays) {
  final unique = <int>{};
  for (final days in leadDays) {
    if (!NotificationKind.leadDayChoices.contains(days)) return null;
    unique.add(days);
  }
  return List.unmodifiable(unique.toList()..sort((a, b) => b - a));
}

/// Stored form of a lead-time list: `30,7,0`; empty for none.
String encodeLeadDays(List<int> leadDays) => leadDays.join(',');

/// Parses [encodeLeadDays]' form. Returns `null` for anything malformed or
/// outside the choices, so the caller can fall back to a default.
List<int>? decodeLeadDays(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return const [];
  final parsed = <int>[];
  for (final part in trimmed.split(',')) {
    final days = int.tryParse(part.trim());
    if (days == null) return null;
    parsed.add(days);
  }
  return normaliseLeadDays(parsed);
}

/// design-v1's single `lead_days` value as one of today's choices.
///
/// design-v1 offered 1, 3, 7, 14, 30 on the guest drawer and 2, 7, 30 for
/// signed-in drawers. A value that is a choice stays; anything else becomes
/// the nearest *earlier-warning* choice (the smallest choice above it, so 2
/// becomes 3 and the user is never warned later than before), or 30 when it
/// is above every choice.
int migrateLegacyLeadDays(int legacy) {
  const choices = NotificationKind.leadDayChoices;
  if (choices.contains(legacy)) return legacy;
  for (final choice in choices) {
    if (choice > legacy) return choice;
  }
  return choices.last;
}
