import 'package:sqflite/sqflite.dart';

import '../../core/failure/app_failure.dart';
import '../../core/failure/failure_mapper.dart';

/// Maps sqflite errors to [StorageFailure]s for the [FailureMapper] chain.
///
/// SQLite reports problems as result codes inside the message text
/// (standard sqflite behaviour), so we match on the code names.
final class SqfliteFailureRule implements FailureRule {
  const SqfliteFailureRule();

  @override
  AppFailure? tryMap(Object error, StackTrace stackTrace) {
    if (error is! DatabaseException) return null;
    final text = error.toString().toUpperCase();
    final kind = switch (text) {
      _ when text.contains('SQLITE_FULL') || text.contains('DISK IS FULL') =>
        StorageFailureKind.full,
      _ when text.contains('SQLITE_CORRUPT') ||
          text.contains('SQLITE_NOTADB') ||
          text.contains('NOT A DATABASE') =>
        StorageFailureKind.corrupt,
      _ => StorageFailureKind.writeFailed,
    };
    return StorageFailure(kind, cause: error, stackTrace: stackTrace);
  }
}
