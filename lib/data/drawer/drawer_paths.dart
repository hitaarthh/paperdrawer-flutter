import 'dart:convert';

import 'package:path/path.dart' as p;

import '../../core/result/result.dart';
import '../../domain/account/account_scope.dart';

/// Where each drawer lives on disk. The only code that knows the layout.
///
/// The layout is the one design-v1 already ships (existing drawers must keep
/// opening), under `<Application Support>/paperdrawer/`:
///
/// ```
/// vault.sqlite + attachments/                      guest (Base)
/// accounts/<project-key>/<user-uuid>/vault.sqlite  one per account
///                        + attachments/  (+ legacy claim-photos/)
/// ```
///
/// Rows store attachment paths relative to the drawer folder.
final class DrawerPaths {
  const DrawerPaths(this.root);

  /// `<Application Support>/paperdrawer`.
  final String root;

  static const databaseFileName = 'vault.sqlite';
  static const attachmentsFolderName = 'attachments';

  /// The project key for a Supabase origin: base64url of the origin, so
  /// staging and production never share a drawer even if user IDs match.
  static String projectKeyFor(Uri supabaseUrl) =>
      base64Url.encode(utf8.encode(supabaseUrl.origin));

  /// Builds the scope for a signed-in user of [supabaseUrl].
  static Result<UserScope> userScope(Uri supabaseUrl, String userId) =>
      UserScope.parse(projectKey: projectKeyFor(supabaseUrl), userId: userId);

  /// The folder holding [scope]'s database and attachments.
  String folder(AccountScope scope) => switch (scope) {
    GuestScope() => root,
    UserScope(:final projectKey, :final id) => p.join(
      root,
      'accounts',
      projectKey,
      id,
    ),
  };

  String database(AccountScope scope) =>
      p.join(folder(scope), databaseFileName);

  String attachments(AccountScope scope) =>
      p.join(folder(scope), attachmentsFolderName);
}
