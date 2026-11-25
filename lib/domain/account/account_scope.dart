import 'package:flutter/foundation.dart';

import '../../core/failure/app_failure.dart';
import '../../core/id/id_generator.dart';
import '../../core/result/result.dart';

/// Whose drawer is open.
///
/// Every account has its own folder and database file on the phone, keyed by
/// its user ID (never the email, which can change). Signing out closes the
/// file and never deletes it, so two people can share one iPhone without
/// losing or seeing each other's data. One database per account means a
/// missing `WHERE owner = ?` can never leak one person's bills to another.
///
/// Layout under the app's Application Support folder:
///
/// ```
/// drawers/guest/vault.db             + originals/
/// drawers/<user-uuid>/vault.db       + originals/
/// ```
@immutable
sealed class AccountScope {
  const AccountScope();

  /// The folder for this scope, relative to the drawers root.
  String get folderName;

  static const databaseFileName = 'vault.db';
  static const originalsFolderName = 'originals';

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
  String get folderName => 'guest';

  @override
  bool operator ==(Object other) => other is GuestScope;

  @override
  int get hashCode => (GuestScope).hashCode;
}

/// A signed-in PaperDrawer account.
final class UserScope extends AccountScope {
  const UserScope._(this.id);

  /// Validates [userId] before it is ever used in a file path. Anything that
  /// isn't a UUID (an empty string, `../`, an email) is refused, so a bad
  /// value from the server can't point at another folder.
  static Result<UserScope> parse(String userId) {
    final normalised = userId.trim().toLowerCase();
    if (!isUuid(normalised)) {
      return Err(
        StorageFailure(
          StorageFailureKind.corrupt,
          cause: ArgumentError.value(userId, 'userId', 'not a UUID'),
        ),
      );
    }
    return Ok(UserScope._(normalised));
  }

  final String id;

  @override
  String get folderName => id;

  @override
  bool operator ==(Object other) => other is UserScope && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'UserScope($id)';
}
