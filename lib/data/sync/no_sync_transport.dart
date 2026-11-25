import 'package:flutter/foundation.dart';

import '../../core/result/result.dart';
import '../../domain/account/account_scope.dart';
import '../../domain/plans/plan.dart';
import '../../domain/sync/sync_status.dart';
import '../../domain/sync/sync_transport.dart';

/// Base: nothing leaves the phone (null object).
///
/// Using a real object instead of `null` means callers never branch on "is
/// there a transport?".
final class NoSyncTransport implements SyncTransport {
  NoSyncTransport();

  final ValueNotifier<SyncStatus> _status = ValueNotifier(const SyncOff());

  @override
  SyncKind get kind => SyncKind.none;

  @override
  ValueListenable<SyncStatus> get status => _status;

  @override
  Future<Result<Unit>> start(UserScope scope, {bool fullUpload = false}) async =>
      const Ok(unit);

  @override
  Future<Result<Unit>> requestSync() async => const Ok(unit);

  @override
  Future<void> stop() async {}

  @override
  void dispose() => _status.dispose();
}
