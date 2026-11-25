import 'package:sqflite/sqflite.dart';

import '../../core/failure/app_failure.dart';
import '../../core/failure/failure_mapper.dart';

/// Maps sqflite errors to [StorageFailure]s for the [FailureMapper] chain.
///
/// Uses SQLite's primary result codes (standard SQLite behaviour), not the
/// message text. The original exception is NOT kept as the cause: its text
/// contains the SQL and its arguments (item names, amounts). Only a sanitised
/// marker with the result code is kept.
final class SqfliteFailureRule implements FailureRule {
  const SqfliteFailureRule();

  // SQLite primary result codes (sqlite.org/rescode.html).
  static const _busy = 5;
  static const _locked = 6;
  static const _corrupt = 11;
  static const _full = 13;
  static const _constraint = 19;
  static const _notADatabase = 26;

  @override
  AppFailure? tryMap(Object error, StackTrace stackTrace) {
    if (error is! DatabaseException) return null;
    // The database closes when its account is switched: the work belonged
    // to a scope that no longer exists, so stay silent.
    if (error.isDatabaseClosedError()) return const ScopeClosedFailure();
    // Extended codes carry the primary code in the low byte.
    final code = (error.getResultCode() ?? -1) & 0xff;
    final kind = switch (code) {
      _full => StorageFailureKind.full,
      _corrupt || _notADatabase => StorageFailureKind.corrupt,
      _busy || _locked => StorageFailureKind.busy,
      _constraint => StorageFailureKind.constraintViolated,
      _ => StorageFailureKind.writeFailed,
    };
    return StorageFailure(
      kind,
      cause: SqliteResultCode(code),
      stackTrace: stackTrace,
    );
  }
}

/// A content-free stand-in for a [DatabaseException], safe to log.
final class SqliteResultCode {
  const SqliteResultCode(this.code);

  final int code;

  @override
  String toString() => 'SQLite result code $code';
}
