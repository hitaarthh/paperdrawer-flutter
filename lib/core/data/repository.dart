import 'dart:async';

import 'package:flutter/foundation.dart';

import '../concurrency/serial_queue.dart';
import '../failure/app_failure.dart';
import '../failure/failure_mapper.dart';
import '../logging/app_logger.dart';
import '../result/result.dart';

/// The base class for every repository (template method).
///
/// A repository is the single source of truth for one kind of data in the
/// open drawer's database. This class owns the parts every repository must
/// get exactly right, so subclasses can't vary them:
///
/// - **One snapshot in memory** ([snapshot]) that screens read synchronously.
/// - **One serial write queue**, normally shared by every repository of the
///   same drawer (pass the drawer session's queue), so writes across
///   repositories never interleave either.
/// - **No thrown errors.** Every public operation returns a [Result]; thrown
///   errors are turned into [AppFailure]s by the injected [FailureMapper].
/// - **Notify only on success**, after the snapshot reflects the write.
/// - **Closing on account switch.** After [close], writes return
///   [ScopeClosedFailure] so late work can't land in another account.
///
/// Rules for subclasses:
/// - Every database change inside one [write] runs in one transaction.
/// - Return `Err` only *before* changing anything; inside a transaction,
///   abort with `throw FailureException(failure)` so it rolls back.
/// - Never call [write], [load] or [close] from inside a [write] operation
///   (it would deadlock; it is caught and reported as a bug).
/// - Plan limits are checked inside the write, not before it, so two
///   entry points can't both pass the check.
///
/// ```dart
/// final class ItemRepository extends Repository<ItemSnapshot> {
///   Future<Result<Item>> archive(String id) => write('archive', () async {
///     final item = snapshot.byId(id);
///     if (item == null) return Err(NotFoundFailure('item', id));
///     await _store.setArchived(id, clock.now());
///     return Ok(item);
///   });
/// }
/// ```
abstract base class Repository<S extends Object> extends ChangeNotifier {
  Repository({
    required String name,
    required FailureMapper failures,
    required AppLogger logger,
    SerialQueue? queue,
  }) : _name = name,
       _failures = failures,
       _logger = logger,
       _queue = queue ?? SerialQueue(),
       _ownsQueue = queue == null;

  final String _name;
  final FailureMapper _failures;
  final AppLogger _logger;
  final SerialQueue _queue;
  final bool _ownsQueue;

  S? _snapshot;
  bool _closed = false;
  bool _disposed = false;
  bool _stale = false;
  bool _replaced = false;
  Future<void>? _closing;

  /// True once [load] has succeeded at least once.
  bool get isLoaded => _snapshot != null;

  /// True when a write succeeded but re-reading the snapshot failed. The next
  /// [load] or successful write clears it.
  bool get isStale => _stale;

  /// True after [close] or [dispose].
  bool get isClosed => _closed;

  /// The in-memory state. Reading it before [load] succeeded is a programmer
  /// error; screens that may outlive a failed load use [snapshotOrNull].
  @protected
  S get snapshot {
    final value = _snapshot;
    if (value == null) {
      throw StateError('$_name read before load()');
    }
    return value;
  }

  /// The in-memory state, or `null` before the first successful [load].
  @protected
  S? get snapshotOrNull => _snapshot;

  @protected
  AppLogger get logger => _logger;

  /// Reads the full state from storage. Called by [load] and after each
  /// successful [write] (unless the write asks not to refresh).
  @protected
  Future<S> readSnapshot();

  /// Loads (or reloads) the snapshot. Safe to call more than once; sync
  /// calls it after applying remote changes.
  Future<Result<Unit>> load() => _run('load', () async {
    await _refresh();
    return const Ok(unit);
  });

  /// Runs [operation] on the write queue and returns its result.
  ///
  /// - Thrown errors become `Err` through the [FailureMapper].
  /// - On `Ok`, the snapshot is re-read (unless [refresh] is false, in which
  ///   case the operation must call [replaceSnapshot] before returning `Ok`)
  ///   and listeners are notified.
  /// - On `Err`, nothing changes and listeners are not notified.
  @protected
  Future<Result<T>> write<T>(
    String action,
    Future<Result<T>> Function() operation, {
    bool refresh = true,
  }) => _run(action, () async {
    _replaced = false;
    final result = await operation();
    if (result.isOk) {
      if (refresh) {
        await _refreshAfterWrite(action);
      } else {
        assert(
          _replaced,
          '$_name.$action: write(refresh: false) must call replaceSnapshot',
        );
      }
    }
    return result;
  });

  /// Sets the snapshot without a re-read, for writes that already know the
  /// new state. Only call from inside a [write] operation.
  @protected
  void replaceSnapshot(S next) {
    _snapshot = next;
    _stale = false;
    _replaced = true;
  }

  /// Refuses new writes, then completes when the ones already queued have
  /// finished. Call before closing the database. Safe to call more than once;
  /// every call waits.
  Future<void> close() => _closing ??= () {
    _closed = true;
    return _ownsQueue ? _queue.close() : _queue.idle();
  }();

  /// Also closes, so a forgotten [close] can't leave writes accepted. The
  /// owner should still `await close()` before closing the database.
  @override
  @mustCallSuper
  void dispose() {
    _disposed = true;
    unawaited(close());
    super.dispose();
  }

  Future<Result<T>> _run<T>(
    String action,
    Future<Result<T>> Function() operation,
  ) async {
    if (_closed || _queue.isClosed) {
      return Err<T>(const ScopeClosedFailure());
    }
    if (_queue.isInsideOperation) {
      final bug = StateError(
        '$_name.$action called from inside another write (deadlock)',
      );
      assert(false, bug.message);
      _logger.log(LogLevel.error, bug.message, error: bug);
      return Err<T>(UnexpectedFailure(cause: bug, stackTrace: StackTrace.current));
    }
    // Work accepted before close() still runs: it belongs to this account
    // and its database stays open until close() completes.
    return _queue.run(() async {
      try {
        final result = await operation();
        switch (result) {
          case Ok():
            _notify();
          case Err(:final failure):
            _logger.failure('$_name.$action', failure);
        }
        return result;
      } catch (error, stackTrace) {
        final failure = _failures.map(error, stackTrace);
        _logger.failure('$_name.$action', failure);
        return Err<T>(failure);
      }
    });
  }

  Future<void> _refresh() async {
    _snapshot = await readSnapshot();
    _stale = false;
  }

  /// The write itself is committed at this point. If re-reading fails we must
  /// not report the write as failed (the user would retry and duplicate it),
  /// so keep the old snapshot, mark it stale and log.
  Future<void> _refreshAfterWrite(String action) async {
    try {
      await _refresh();
    } catch (error, stackTrace) {
      _stale = true;
      _logger.log(
        LogLevel.error,
        '$_name.$action: snapshot refresh failed after a committed write '
        '(${error.runtimeType})',
        stackTrace: stackTrace,
      );
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }
}
