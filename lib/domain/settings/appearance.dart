import 'package:flutter/foundation.dart';

import '../../core/result/result.dart';

/// Settings › Appearance. The canvas default is [system].
enum AppearanceMode {
  system('system'),
  light('light'),
  dark('dark');

  const AppearanceMode(this.storageValue);

  /// The value written to the `appearance` settings key.
  final String storageValue;

  /// Parses a stored value; anything unknown or missing is [system].
  static AppearanceMode fromStorage(String? value) {
    for (final mode in values) {
      if (mode.storageValue == value) return mode;
    }
    return system;
  }
}

/// Where the appearance choice is kept (port). Wave 2 implements it over the
/// settings table (key `appearance`, values [AppearanceMode.storageValue]);
/// it syncs with the other settings for signed-in accounts.
abstract interface class AppearanceStore {
  /// The stored choice; [AppearanceMode.system] when nothing is stored.
  ///
  /// Fails with a `StorageFailure` when the settings can't be read.
  Future<Result<AppearanceMode>> read();

  /// Saves [mode].
  ///
  /// Fails with a `StorageFailure` when the settings can't be written; the
  /// stored value is then unchanged.
  Future<Result<Unit>> write(AppearanceMode mode);

  /// Notifies when the stored value changed elsewhere (settings sync from
  /// another device, another screen).
  Listenable get changes;
}
