import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrawer/core/failure/app_failure.dart';
import 'package:paperdrawer/data/drawer/drawer_paths.dart';
import 'package:paperdrawer/domain/account/account_scope.dart';

void main() {
  const id = '2F1D1A52-6C1E-4B8E-9D55-0D7C3B7F9A10';
  final staging = Uri.parse('https://staging.supabase.co');
  final production = Uri.parse('https://prod.supabase.co');

  test('a user scope is the normalised UUID in one project', () {
    final scope = DrawerPaths.userScope(staging, ' $id ').requireValue;
    expect(scope.id, id.toLowerCase());
    expect(scope.userId, id.toLowerCase());
    expect(scope.isGuest, isFalse);
  });

  test('the same user in two projects gets two drawers', () {
    final a = DrawerPaths.userScope(staging, id).requireValue;
    final b = DrawerPaths.userScope(production, id).requireValue;
    expect(a, isNot(b));
    const paths = DrawerPaths('/support/paperdrawer');
    expect(paths.database(a), isNot(paths.database(b)));
  });

  test('anything that is not a UUID is refused before touching a path', () {
    for (final bad in ['', '../guest', 'clara@example.com', '$id/..', 'guest']) {
      final result = DrawerPaths.userScope(staging, bad);
      expect(result.isErr, isTrue, reason: bad);
      expect(
        result.failureOrNull,
        const AuthFailure(AuthFailureKind.sessionRejected),
      );
    }
  });

  test('a project key with path characters is refused', () {
    expect(
      UserScope.parse(projectKey: '../x', userId: id).isErr,
      isTrue,
    );
  });

  test('paths match the layout design-v1 already ships', () {
    const paths = DrawerPaths('/support/paperdrawer');
    final user = DrawerPaths.userScope(staging, id).requireValue;
    final key = DrawerPaths.projectKeyFor(staging);
    expect(paths.database(const GuestScope()), '/support/paperdrawer/vault.sqlite');
    expect(
      paths.database(user),
      '/support/paperdrawer/accounts/$key/${id.toLowerCase()}/vault.sqlite',
    );
    expect(
      paths.attachments(const GuestScope()),
      '/support/paperdrawer/attachments',
    );
  });

  test('the guest has no user ID', () {
    const guest = GuestScope();
    expect(guest.userId, isNull);
    expect(guest.isGuest, isTrue);
  });
}
