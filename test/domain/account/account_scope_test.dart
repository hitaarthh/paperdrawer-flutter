import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrawer/core/failure/app_failure.dart';
import 'package:paperdrawer/domain/account/account_scope.dart';

void main() {
  const id = '2F1D1A52-6C1E-4B8E-9D55-0D7C3B7F9A10';

  test('a user folder is the normalised UUID', () {
    final scope = UserScope.parse(' $id ').requireValue;
    expect(scope.folderName, id.toLowerCase());
    expect(scope.userId, id.toLowerCase());
    expect(scope.isGuest, isFalse);
  });

  test('the same user ID always maps to the same drawer', () {
    expect(UserScope.parse(id).requireValue, UserScope.parse(id.toLowerCase()).requireValue);
  });

  test('anything that is not a UUID is refused before touching a path', () {
    for (final bad in ['', '../guest', 'clara@example.com', '$id/..', 'guest']) {
      final result = UserScope.parse(bad);
      expect(result.isErr, isTrue, reason: bad);
      expect(result.failureOrNull, const StorageFailure(StorageFailureKind.corrupt));
    }
  });

  test('the guest drawer has its own folder and no user ID', () {
    const guest = GuestScope();
    expect(guest.folderName, 'guest');
    expect(guest.userId, isNull);
    expect(guest.isGuest, isTrue);
  });
}
