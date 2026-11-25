import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrawer/domain/account/account_scope.dart';
import 'package:paperdrawer/domain/sync/sync_transport.dart';

/// The behaviour every [SyncTransport] must have. Call it from a test file
/// for each implementation (no-sync, CloudKit with a fake channel, Supabase
/// with a fake client).
///
/// Transports are single-use: start once, stop, dispose.
void syncTransportContract(String name, SyncTransport Function() create) {
  group('$name meets the SyncTransport contract', () {
    final scope = UserScope.parse(
      projectKey: 'cHJvamVjdA',
      userId: '2f1d1a52-6c1e-4b8e-9d55-0d7c3b7f9a10',
    ).requireValue;

    test('start, requestSync, stop and dispose never throw', () async {
      final transport = create();
      expect((await transport.start(scope)).isOk, isTrue);
      expect((await transport.requestSync()).isOk, isTrue);
      await transport.stop();
      transport.dispose();
    });

    test('stop is safe before start and twice', () async {
      final transport = create();
      await transport.stop();
      await transport.stop();
      transport.dispose();
    });

    test('status is readable before start', () {
      final transport = create();
      expect(transport.status.value, isNotNull);
      transport.dispose();
    });
  });
}
