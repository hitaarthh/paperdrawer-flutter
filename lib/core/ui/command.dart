import 'package:flutter/foundation.dart';

import '../failure/app_failure.dart';
import '../result/result.dart';

/// A user action a view model exposes to its view (command pattern, as in the
/// Flutter architecture guide).
///
/// A command owns the parts every action must get right:
///
/// - **No double submit.** While [running], calling `execute` again returns
///   the in-flight future instead of starting a second save.
/// - **Observable state.** [running], [result] and [failure] drive spinners,
///   disabled buttons and inline errors without extra fields in the view
///   model.
/// - **Never throws.** The action returns a [Result]; a thrown error is a bug
///   and becomes [UnexpectedFailure] so the UI still recovers.
///
/// Use [Command0] for actions without input and [Command1] for actions with
/// one argument.
abstract base class Command<T> extends ChangeNotifier {
  Command();

  Future<Result<T>>? _inFlight;
  Result<T>? _result;
  bool _disposed = false;

  bool get running => _inFlight != null;

  /// The result of the last finished run, until [clear] is called.
  Result<T>? get result => _result;

  /// The failure of the last run, if it failed and isn't silent.
  AppFailure? get failure => switch (_result) {
    Err(:final failure) when !failure.isSilent => failure,
    _ => null,
  };

  bool get completed => _result?.isOk ?? false;

  /// Forgets the last result (for example after showing its error).
  void clear() {
    if (_result == null) return;
    _result = null;
    _notify();
  }

  @protected
  Future<Result<T>> run(Future<Result<T>> Function() action) {
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;
    _result = null;
    final future = _guard(action);
    _inFlight = future;
    _notify();
    return future;
  }

  Future<Result<T>> _guard(Future<Result<T>> Function() action) async {
    Result<T> result;
    try {
      result = await action();
    } catch (error, stackTrace) {
      result = Err(UnexpectedFailure(cause: error, stackTrace: stackTrace));
    }
    _result = result;
    _inFlight = null;
    _notify();
    return result;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// A command without input, such as "Export" or "Sign out".
final class Command0<T> extends Command<T> {
  Command0(this._action);

  final Future<Result<T>> Function() _action;

  Future<Result<T>> execute() => run(_action);
}

/// A command with one input, such as "Archive item(id)".
final class Command1<A, T> extends Command<T> {
  Command1(this._action);

  final Future<Result<T>> Function(A argument) _action;

  Future<Result<T>> execute(A argument) => run(() => _action(argument));
}
