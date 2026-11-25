import 'package:flutter/foundation.dart';

import '../result/result.dart';
import 'command.dart';

/// The base class for every screen's view model (MVVM).
///
/// A view model:
/// - reads from repositories and use cases, never from the database, files or
///   plugins directly;
/// - exposes derived, ready-to-render data as getters, so widgets compute
///   nothing;
/// - exposes user actions as [Command]s made with [command0]/[command1];
/// - never throws to the view.
///
/// This base class handles the lifecycle traps:
/// - [listenTo] subscribes to sources and unsubscribes on [dispose], so a
///   closed screen never leaks a listener on a long-lived repository;
/// - [notifyListeners] is a no-op after [dispose], so an `await` that
///   finishes after the user left the screen can't throw;
/// - commands made here are disposed with the view model, and their state
///   changes notify the view model's listeners;
/// - [onSourceChanged] is the one place to recompute derived state.
abstract base class ViewModel extends ChangeNotifier {
  final List<Listenable> _sources = [];
  final List<Command<Object?>> _commands = [];
  bool _disposed = false;

  bool get isDisposed => _disposed;

  /// Rebuilds derived state and notifies listeners whenever [source] changes.
  @protected
  void listenTo(Listenable source) {
    if (_disposed) return;
    _sources.add(source);
    source.addListener(_handleSourceChanged);
  }

  /// A command owned by this view model.
  @protected
  Command0<T> command0<T>(Future<Result<T>> Function() action) =>
      _own(Command0<T>(action));

  /// A one-argument command owned by this view model.
  @protected
  Command1<A, T> command1<A, T>(Future<Result<T>> Function(A) action) =>
      _own(Command1<A, T>(action));

  /// Recompute derived state here. Called after any [listenTo] source changes,
  /// then listeners are notified. The default does nothing.
  @protected
  void onSourceChanged() {}

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  C _own<C extends Command<Object?>>(C command) {
    _commands.add(command);
    command.addListener(notifyListeners);
    return command;
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
    for (final command in _commands) {
      command.dispose();
    }
    _commands.clear();
    super.dispose();
  }
}
