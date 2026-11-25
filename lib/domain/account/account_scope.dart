import 'package:flutter/foundation.dart';

import '../../core/failure/app_failure.dart';
import '../../core/id/id_generator.dart';
import '../../core/result/result.dart';

/// Whose drawer is open.
///
/// Every account has its own database file on the phone, keyed by the
/// Supabase project and the user ID (never the email, which can change).
/// Signing out closes the file and never deletes it, so two people can share
/// one iPhone without losing or seeing each other's data. One database per
/// account means a missing `WHERE owner = ?` can never leak one person's
/// bills to another.
///
/// Where the files live is a data-layer concern (`DrawerPaths`); this type
/// only identifies the owner.
@immutable
sealed class AccountScope {
  const AccountScope();

  bool get isGuest => this is GuestScope;

  /// The user ID, or `null` for the guest.
  String? get userId => switch (this) {
    GuestScope() => null,
    UserScope(:final id) => id,
  };
}

/// No one signed in: the Base drawer on this device.
final class GuestScope extends AccountScope {
  const GuestScope();

  @override
  bool operator ==(Object other) => other is GuestScope;

  @override
  int get hashCode => (GuestScope).hashCode;

  @override
  String toString() => 'GuestScope()';
}

/// A signed-in PaperDrawer account in one backend project.
///
/// [projectKey] separates backends (staging and production never share a
/// drawer). It is base64url of the Supabase origin, made by the data layer.
final class UserScope extends AccountScope {
  const UserScope._(this.projectKey, this.id);

  /// Validates both parts before they are ever used in a file path. A user ID
  /// that isn't a UUID, or a project key with characters outside base64url,
  /// is refused, so a bad value from the server can't point at another
  /// folder. A refused ID means the session can't be trusted:
  /// [AuthFailureKind.sessionRejected].
  static Result<UserScope> parse({
    required String projectKey,
    required String userId,
  }) {
    final id = userId.trim().toLowerCase();
    if (!isUuid(id) || !_projectKey.hasMatch(projectKey)) {
      return Err(
        AuthFailure(
          AuthFailureKind.sessionRejected,
          cause: ArgumentError('invalid account scope'),
        ),
      );
    }
    return Ok(UserScope._(projectKey, id));
  }

  final String projectKey;
  final String id;

  @override
  bool operator ==(Object other) =>
      other is UserScope && other.projectKey == projectKey && other.id == id;

  @override
  int get hashCode => Object.hash(projectKey, id);

  @override
  String toString() => 'UserScope($projectKey, $id)';

  static final _projectKey = RegExp(r'^[A-Za-z0-9_-]{1,200}={0,2}$');
}
