import 'dart:async';

/// Runs async operations one at a time, in the order they were submitted.
///
/// Repositories share one queue per open drawer, so two taps can never
/// interleave half-finished database work. A failing operation does not block
/// the ones after it: its error goes to its own caller only.
///
/// **Never submit from inside a running operation.** The inner operation
/// would wait for the outer one, which waits for the inner one: a deadlock.
/// [run] detects this and throws a [StateError] instead of hanging.
final class SerialQueue {
  Future<void> _tail = Future<void>.value();
  int _pending = 0;
  bool _closed = false;
  Future<void>? _closing;

  /// Marks code running inside one of this queue's operations.
  late final Object _zoneKey = Object();

  /// Operations submitted and not yet finished.
  int get pending => _pending;

  bool get isClosed => _closed;

  /// True when called from inside one of this queue's operations.
  bool get isInsideOperation => Zone.current[_zoneKey] == true;

  /// Queues [operation] and completes with its result or error.
  ///
  /// Throws [StateError] after [close], or when called from inside an
  /// operation of this queue (re-entrancy). Both are programmer errors.
  Future<T> run<T>(Future<T> Function() operation) {
    if (_closed) {
      throw StateError('SerialQueue.run after close');
    }
    if (isInsideOperation) {
      throw StateError(
        'SerialQueue.run from inside a queued operation would deadlock',
      );
    }
    _pending++;
    final result = _tail.then(
      (_) => runZoned(operation, zoneValues: {_zoneKey: true}),
    );
    _tail = result.then<void>(
      (_) {
        _pending--;
      },
      onError: (Object _, StackTrace _) {
        _pending--;
      },
    );
    return result;
  }

  /// Completes when everything submitted so far has finished, without
  /// closing the queue.
  Future<void> idle() => _tail;

  /// Refuses new work, then completes when everything already queued has
  /// finished. Safe to call more than once; every call waits.
  Future<void> close() => _closing ??= () {
    _closed = true;
    return _tail;
  }();
}
