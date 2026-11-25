import 'package:flutter/foundation.dart';

import '../../core/concurrency/serial_queue.dart';
import '../../core/failure/app_failure.dart';
import '../../core/logging/app_logger.dart';
import '../../core/result/result.dart';
import '../../domain/account/account_scope.dart';
import '../../domain/plans/active_plan.dart';
import '../../domain/plans/plan.dart';
import '../../domain/sync/sync_status.dart';
import '../../domain/sync/sync_transport.dart';
import 'no_sync_transport.dart';

/// Keeps exactly one sync transport running, for the open drawer's plan.
///
/// Guarantees (spec: "Two never run at the same time. Switching plans hands
/// over cleanly"):
/// - At most one transport is started at any time.
/// - Switching stops the old transport (letting its upload finish) before
///   the new one starts.
/// - Requests are serialized, so a quick sign-out/sign-in or two plan
///   updates can't interleave.
/// - [status] always reflects the current transport.
final class SyncCoordinator {
  SyncCoordinator({
    required SyncTransportFactory factory,
    required AppLogger logger,
  }) : _factory = factory,
       _logger = logger;

  final SyncTransportFactory _factory;
  final AppLogger _logger;
  final SerialQueue _queue = SerialQueue();
  final ValueNotifier<SyncStatus> _status = ValueNotifier(const SyncOff());

  SyncTransport _current = NoSyncTransport();
  UserScope? _scope;

  ValueListenable<SyncStatus> get status => _status;

  SyncKind get activeKind => _current.kind;

  /// Makes the running transport match [plan] for [scope].
  ///
  /// Pass [fullUpload] when a plan change asks for it
  /// (`StartSyncWithFullUpload`); a normal app start does not.
  Future<Result<Unit>> activate({
    required AccountScope scope,
    required ActivePlan plan,
    bool fullUpload = false,
  }) => _queue.run(() async {
    final userScope = switch (scope) {
      UserScope() => scope,
      GuestScope() => null,
    };
    final wanted = plan.canSync && userScope != null
        ? plan.policy.syncKind
        : SyncKind.none;

    final unchanged = wanted == _current.kind && userScope == _scope;
    if (unchanged && !fullUpload) return const Ok(unit);

    // A transport is bound to one account, so any change (kind, account, or
    // a requested full upload) gets a fresh instance after the old one stops.
    await _swapTo(
      wanted == SyncKind.none ? NoSyncTransport() : _factory.create(wanted),
    );
    _scope = userScope;
    if (userScope == null || wanted == SyncKind.none) return const Ok(unit);

    final started = await _current.start(userScope, fullUpload: fullUpload);
    if (started case Err(:final failure)) {
      _logger.failure('SyncCoordinator.activate', failure);
    }
    return started;
  });

  /// Stops syncing (sign-out, account switch). Local data is untouched.
  Future<void> deactivate() => _queue.run(() async {
    await _swapTo(NoSyncTransport());
    _scope = null;
  });

  /// Asks the current transport to sync soon. A no-op on Base.
  Future<Result<Unit>> requestSync() async {
    if (_scope == null) return const Ok(unit);
    try {
      return await _current.requestSync();
    } catch (error, stackTrace) {
      return Err(UnexpectedFailure(cause: error, stackTrace: stackTrace));
    }
  }

  Future<void> _swapTo(SyncTransport next) async {
    final previous = _current;
    previous.status.removeListener(_forwardStatus);
    if (!identical(previous, next)) {
      await previous.stop();
    }
    _current = next;
    next.status.addListener(_forwardStatus);
    _forwardStatus();
  }

  void _forwardStatus() => _status.value = _current.status.value;
}
