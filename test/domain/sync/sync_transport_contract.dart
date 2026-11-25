import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrawer/domain/account/account_scope.dart';
import 'package:paperdrawer/domain/sync/sync_transport.dart';

/// The behaviour every [SyncTransport] must have. Call it from a test file
/// for each implementation (no-sync, CloudKit fake channel, Supabase fake).
void syncTransportContract(
  String name,
  SyncTransport Function() create,
) {
  group('$name meets the SyncTransport contract', () {
    final scope = UserScope.parse(
      '2f1d1a52-6c1e-4b8e-9d55-0d7c3b7f9a10',
    ).requireValue;

    test('start, requestSync and stop never throw', () async {
      final transport = create();
      expect((await transport.start(scope)).isOk, isTrue);
      expect((await transport.requestSync()).isOk, isTrue);
      await transport.stop();
    });

    test('stop is safe to call twice and before start', () async {
      final transport = create();
      await transport.stop();
      await transport.start(scope);
      await transport.stop();
      await transport.stop();
    });

    test('status is always readable', () {
      expect(create().status.value, isNotNull);
    });
  });
}
