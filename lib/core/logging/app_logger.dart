import 'package:flutter/foundation.dart';

import '../failure/app_failure.dart';

enum LogLevel { debug, info, warning, error }

/// Where diagnostic messages go.
///
/// PaperDrawer has no crash-reporting or analytics SDK in this layer: logs
/// stay on the device. Never log user content (item names, amounts, file
/// names, emails). Log IDs, counts and failure codes only.
abstract interface class AppLogger {
  void log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  });
}

extension AppLoggerX on AppLogger {
  void debug(String message) => log(LogLevel.debug, message);

  void info(String message) => log(LogLevel.info, message);

  void warning(String message, {Object? error}) =>
      log(LogLevel.warning, message, error: error);

  /// Logs a failure with its cause. Silent failures log at debug level.
  void failure(String where, AppFailure failure) => log(
    failure.isSilent ? LogLevel.debug : LogLevel.warning,
    '$where: ${failure.debugDescription}',
    error: failure.cause,
    stackTrace: failure.stackTrace,
  );
}

/// Prints to the debug console in debug builds; silent in release.
final class DebugConsoleLogger implements AppLogger {
  const DebugConsoleLogger();

  @override
  void log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!kDebugMode) return;
    debugPrint('[${level.name}] $message${error == null ? '' : ' · $error'}');
    if (stackTrace != null && level == LogLevel.error) {
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}

/// Records entries in memory. For tests.
final class MemoryLogger implements AppLogger {
  final List<(LogLevel, String)> entries = [];

  @override
  void log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) => entries.add((level, message));
}
