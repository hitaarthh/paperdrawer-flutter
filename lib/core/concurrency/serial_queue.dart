import 'dart:async';

/// Runs async operations one at a time, in the order they were submitted.
///
/// Repositories use one queue for all writes so two taps can never interleave
/// half-finished database work. A failing operation does not block the ones
/// after it: its error goes to its own caller only.
final class SerialQueue {
  Future<void> _tail = Future<void>.value();
  int _pending = 0;
  bool _closed = false;

  /// Operations submitted and not yet finished.
  int get pending => _pending;

  bool get isClosed => _closed;

  /// Queues [operation] and completes with its result or error.
  ///
  /// Throws [StateError] after [close]. Callers that may race with close
  /// should check [isClosed] first (the base repository does).
  Future<T> run<T>(Future<T> Function() operation) {
    if (_closed) {
      throw StateError('SerialQueue.run after close');
    }
    _pending++;
    final result = _tail.then((_) => operation());
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

  /// Waits for everything already queued, then refuses new work.
  Future<void> close() async {
    _closed = true;
    await _tail;
  }
}
