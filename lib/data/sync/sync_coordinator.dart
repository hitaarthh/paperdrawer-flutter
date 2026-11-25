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
/// - Switching stops (drains) the old transport before the new one starts,
///   and every transport is used for one account only.
/// - Requests are serialized, so a quick sign-out/sign-in or two plan
///   updates can't interleave.
/// - A failed start is retried by the next [activate] with the same plan.
/// - Never throws: a transport that throws leaves the coordinator on the
///   no-sync transport and returns `Err`.
/// - [status] always reflects the current transport.
///
/// Settings sync is separate: it runs for every signed-in drawer, on every
/// plan, beside this coordinator.
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
  bool _started = false;

  ValueListenable<SyncStatus> get status => _status;

  SyncKind get activeKind => _current.kind;

  /// Makes the running transport match [plan] (which carries its scope).
  ///
  /// Pass [fullUpload] when a plan change asks for it
  /// (`StartSyncWithFullUpload`); a normal app start does not.
  Future<Result<Unit>> activate(ActivePlan plan, {bool fullUpload = false}) =>
      _queue.run(() async {
        final scope = plan.scope;
        final userScope = scope is UserScope ? scope : null;
        final wanted = plan.syncKind;

        final unchanged =
            wanted == _current.kind && userScope == _scope && _started;
        if (unchanged && !fullUpload) return const Ok(unit);
        if (wanted == SyncKind.none && _current.kind == SyncKind.none) {
          _scope = userScope;
          _started = true;
          return const Ok(unit);
        }

        try {
          await _swapTo(
            wanted == SyncKind.none ? NoSyncTransport() : _factory.create(wanted),
          );
          _scope = userScope;
          if (userScope == null || wanted == SyncKind.none) {
            _started = true;
            return const Ok(unit);
          }
          final started = await _current.start(
            userScope,
            fullUpload: fullUpload,
          );
          _started = started.isOk;
          if (started case Err(:final failure)) {
            _logger.failure('SyncCoordinator.activate', failure);
          }
          return started;
        } catch (error, stackTrace) {
          return _recover(error, stackTrace);
        }
      });

  /// Stops syncing (sign-out, account switch). Local data is untouched.
  Future<void> deactivate() => _queue.run(() async {
    try {
      await _swapTo(NoSyncTransport());
    } catch (error, stackTrace) {
      await _recover(error, stackTrace);
    }
    _scope = null;
    _started = false;
  });

  /// Asks the current transport to sync soon. A no-op on Base.
  Future<Result<Unit>> requestSync() async {
    if (_scope == null || !_started) return const Ok(unit);
    try {
      return await _current.requestSync();
    } catch (error, stackTrace) {
      return Err(UnexpectedFailure(cause: error, stackTrace: stackTrace));
    }
  }

  /// Stops and releases everything. The coordinator can't be used after.
  Future<void> dispose() async {
    await deactivate();
    await _queue.close();
    _current.status.removeListener(_forwardStatus);
    _current.dispose();
    _status.dispose();
  }

  Future<void> _swapTo(SyncTransport next) async {
    final previous = _current;
    previous.status.removeListener(_forwardStatus);
    // Point at the new transport before stopping the old one, so a throwing
    // stop() can't leave the coordinator attached to a dead transport.
    _current = next;
    next.status.addListener(_forwardStatus);
    _forwardStatus();
    _started = false;
    try {
      await previous.stop();
    } finally {
      previous.dispose();
    }
  }

  Future<Result<Unit>> _recover(Object error, StackTrace stackTrace) async {
    final failure = UnexpectedFailure(cause: error, stackTrace: stackTrace);
    _logger.failure('SyncCoordinator', failure);
    if (_current.kind != SyncKind.none) {
      final broken = _current;
      broken.status.removeListener(_forwardStatus);
      _current = NoSyncTransport()..status.addListener(_forwardStatus);
      _forwardStatus();
      try {
        await broken.stop();
      } catch (_) {
        // Already failing; the transport is discarded either way.
      } finally {
        broken.dispose();
      }
    }
    _scope = null;
    _started = false;
    return Err(failure);
  }

  void _forwardStatus() => _status.value = _current.status.value;
}
