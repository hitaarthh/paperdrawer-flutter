import 'dart:io';

import 'app_failure.dart';

/// Carries an [AppFailure] through code that can only signal by throwing,
/// such as a sqflite transaction callback that must roll back.
///
/// Throw it deep inside, and the repository's `write` turns it back into an
/// `Err(failure)`. Never let it escape a repository or service.
final class FailureException implements Exception {
  const FailureException(this.failure);

  final AppFailure failure;

  @override
  String toString() => 'FailureException(${failure.debugDescription})';
}

/// One link in the [FailureMapper] chain. Returns `null` when it doesn't
/// recognise the error, so the next link can try.
abstract interface class FailureRule {
  AppFailure? tryMap(Object error, StackTrace stackTrace);
}

/// Turns a thrown error into an [AppFailure] (chain of responsibility).
///
/// The data layer wraps every call into a plugin, the database or the file
/// system with a mapper, so exceptions never reach view models. Rules run in
/// order; the first match wins; anything unmatched becomes an
/// [UnexpectedFailure] with the original error kept for logs.
///
/// Core only knows file-system errors. Extend it with the data layer's rules:
/// `SqfliteFailureRule` for repositories, `NetworkFailureRule` for network
/// adapters only (a local timeout is not "no internet"):
///
/// ```dart
/// final dbFailures = FailureMapper(extraRules: const [SqfliteFailureRule()]);
/// final netFailures = FailureMapper(extraRules: const [NetworkFailureRule()]);
/// ```
class FailureMapper {
  FailureMapper({List<FailureRule> extraRules = const []})
    : _rules = [const _CarriedFailureRule(), ...extraRules, ..._coreRules];

  static const List<FailureRule> _coreRules = [_FileSystemRule()];

  final List<FailureRule> _rules;

  AppFailure map(Object error, StackTrace stackTrace) {
    for (final rule in _rules) {
      final failure = rule.tryMap(error, stackTrace);
      if (failure != null) return failure;
    }
    return UnexpectedFailure(cause: error, stackTrace: stackTrace);
  }
}

final class _CarriedFailureRule implements FailureRule {
  const _CarriedFailureRule();

  @override
  AppFailure? tryMap(Object error, StackTrace stackTrace) =>
      error is FailureException ? error.failure : null;
}

final class _FileSystemRule implements FailureRule {
  const _FileSystemRule();

  /// ENOSPC on Darwin and Linux.
  static const _noSpace = 28;

  @override
  AppFailure? tryMap(Object error, StackTrace stackTrace) {
    if (error is! FileSystemException) return null;
    final kind = error.osError?.errorCode == _noSpace
        ? StorageFailureKind.full
        : StorageFailureKind.writeFailed;
    return StorageFailure(kind, cause: error, stackTrace: stackTrace);
  }
}
