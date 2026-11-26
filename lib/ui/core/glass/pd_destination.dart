import 'package:flutter/foundation.dart';

import '../widgets/icons.dart';

/// One top-level place (Home, Vault, Settings), passed in by the shell. The
/// kit knows nothing about routes.
@immutable
final class PdDestination {
  const PdDestination({
    required this.id,
    required this.label,
    required this.glyph,
    required this.systemIcon,
    this.count,
  });

  /// Kebab-case id; keys are `<id>-tab` (tab bar) and `sidebar-<id>`.
  final String id;

  /// Sentence case: "Home", "Vault", "Settings".
  final String label;

  /// Fallback icon.
  final PdGlyph glyph;

  /// SF Symbol for the iOS 26 tab bar.
  final String systemIcon;

  /// Count shown beside it in the sidebar (Vault's item count), if any.
  final int? count;

  @override
  bool operator ==(Object other) =>
      other is PdDestination &&
      other.id == id &&
      other.label == label &&
      other.glyph == glyph &&
      other.systemIcon == systemIcon &&
      other.count == count;

  @override
  int get hashCode => Object.hash(id, label, glyph, systemIcon, count);
}
