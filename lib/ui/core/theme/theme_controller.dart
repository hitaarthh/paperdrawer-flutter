import 'dart:async';

import 'package:material_ui/material_ui.dart' show Brightness, ThemeMode;

import '../../../core/result/result.dart';
import '../../../core/ui/command.dart';
import '../../../core/ui/view_model.dart';
import '../../../domain/settings/appearance.dart';

/// Holds the Appearance choice for the whole app (MVVM view model).
///
/// Starts at [AppearanceMode.system] so the first frame never waits on
/// storage; call [load] once at startup. [select] changes it at once and
/// saves in the background; a failed save puts the previous choice back and
/// leaves the failure on `select.failure` for the screen to show.
final class ThemeController extends ViewModel {
  ThemeController({required AppearanceStore store}) : _store = store {
    load = command0(_read);
    select = command1(_write);
    listenTo(store.changes);
  }

  final AppearanceStore _store;
  AppearanceMode _mode = AppearanceMode.system;

  /// Reads the stored choice. Fails with the store's failure; the current
  /// mode then stays as it was.
  late final Command0<AppearanceMode> load;

  /// Chooses and saves a mode. Fails with the store's failure, after putting
  /// the previous mode back.
  late final Command1<AppearanceMode, Unit> select;

  AppearanceMode get mode => _mode;

  /// For `MaterialApp.themeMode`.
  ThemeMode get themeMode => switch (_mode) {
    AppearanceMode.system => ThemeMode.system,
    AppearanceMode.light => ThemeMode.light,
    AppearanceMode.dark => ThemeMode.dark,
  };

  /// The brightness to draw with when the platform reports [platform].
  Brightness brightnessFor(Brightness platform) => switch (_mode) {
    AppearanceMode.system => platform,
    AppearanceMode.light => Brightness.light,
    AppearanceMode.dark => Brightness.dark,
  };

  /// The store changed elsewhere: read it again.
  @override
  void onSourceChanged() {
    if (select.running) return;
    unawaited(load.execute());
  }

  Future<Result<AppearanceMode>> _read() async {
    final result = await _store.read();
    if (result case Ok(:final value)) _set(value);
    return result;
  }

  Future<Result<Unit>> _write(AppearanceMode mode) async {
    final previous = _mode;
    _set(mode);
    final result = await _store.write(mode);
    if (result.isErr) _set(previous);
    return result;
  }

  void _set(AppearanceMode mode) {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
  }
}
