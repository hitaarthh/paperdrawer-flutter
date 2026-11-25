import 'package:flutter/foundation.dart';

/// The base class for every screen's view model (MVVM).
///
/// A view model:
/// - reads from repositories and use cases, never from the database, files or
///   plugins directly;
/// - exposes derived, ready-to-render data as getters, so widgets compute
///   nothing;
/// - exposes user actions as `Command`s;
/// - never throws to the view.
///
/// This base class handles the lifecycle traps:
/// - [listenTo] subscribes to sources and unsubscribes on [dispose], so a
///   closed screen never leaks a listener on a long-lived repository;
/// - [emit] is a no-op after [dispose], so an `await` that finishes after the
///   user left the screen can't throw "used after dispose";
/// - [onSourceChanged] is the one place to recompute derived state.
abstract class ViewModel extends ChangeNotifier {
  final List<Listenable> _sources = [];
  bool _disposed = false;

  bool get isDisposed => _disposed;

  /// Rebuilds derived state and notifies listeners whenever [source] changes.
  @protected
  void listenTo(Listenable source) {
    _sources.add(source);
    source.addListener(_handleSourceChanged);
  }

  /// Recompute derived state here. Called after any [listenTo] source changes,
  /// then listeners are notified. The default does nothing.
  @protected
  void onSourceChanged() {}

  /// Notifies listeners unless disposed.
  @protected
  void emit() {
    if (!_disposed) notifyListeners();
  }

  void _handleSourceChanged() {
    if (_disposed) return;
    onSourceChanged();
    notifyListeners();
  }

  @override
  @mustCallSuper
  void dispose() {
    _disposed = true;
    for (final source in _sources) {
      source.removeListener(_handleSourceChanged);
    }
    _sources.clear();
    super.dispose();
  }
}
