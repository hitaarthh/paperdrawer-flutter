import 'dart:async';
import 'dart:io';


import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrawer/core/failure/app_failure.dart';
import 'package:paperdrawer/core/failure/failure_mapper.dart';

final class _AlwaysCancelled implements FailureRule {
  const _AlwaysCancelled();

  @override
  AppFailure? tryMap(Object error, StackTrace stackTrace) =>
      error is ArgumentError ? const CancelledFailure() : null;
}

void main() {
  final mapper = FailureMapper();
  final trace = StackTrace.current;

  test('a carried failure comes back unchanged', () {
    const carried = NotFoundFailure('item', 'x');
    expect(mapper.map(const FailureException(carried), trace), carried);
  });

  test('core does not treat a local timeout as "no internet"', () {
    expect(mapper.map(TimeoutException('slow'), trace), isA<UnexpectedFailure>());
  });

  test('ENOSPC becomes a full-storage failure', () {
    final failure = mapper.map(
      const FileSystemException('write', '/x', OSError('No space', 28)),
      trace,
    );
    expect(failure, const StorageFailure(StorageFailureKind.full));
  });

  test('other file errors become write failures', () {
    final failure = mapper.map(
      const FileSystemException('write', '/x', OSError('Denied', 13)),
      trace,
    );
    expect(failure, const StorageFailure(StorageFailureKind.writeFailed));
  });

  test('unknown errors become UnexpectedFailure and keep the cause', () {
    final error = StateError('bug');
    final failure = mapper.map(error, trace);
    expect(failure, isA<UnexpectedFailure>());
    expect(failure.cause, same(error));
    expect(failure.stackTrace, same(trace));
  });

  test('debug descriptions never include the text of the cause', () {
    final secret = StateError('INSERT … Samsung fridge ₹45,000');
    final unexpected = UnexpectedFailure(cause: secret);
    final storage = StorageFailure(StorageFailureKind.writeFailed, cause: secret);
    expect(unexpected.debugDescription, isNot(contains('Samsung')));
    expect(storage.debugDescription, isNot(contains('Samsung')));
  });

  test('extra rules run before the core rules', () {
    final custom = FailureMapper(extraRules: const [_AlwaysCancelled()]);
    expect(custom.map(ArgumentError('x'), trace), const CancelledFailure());
    expect(custom.map(StateError('x'), trace), isA<UnexpectedFailure>());
  });

  test('silent and retryable flags', () {
    expect(const CancelledFailure().isSilent, isTrue);
    expect(const ScopeClosedFailure().isSilent, isTrue);
    expect(const AuthFailure(AuthFailureKind.cancelled).isSilent, isTrue);
    expect(const AuthFailure(AuthFailureKind.sessionRejected).isSilent, isFalse);
    expect(const PurchaseFailure(PurchaseFailureKind.cancelled).isSilent, isTrue);
    expect(const SyncFailure(SyncPauseReason.offline).isRetryable, isTrue);
    expect(const SyncFailure(SyncPauseReason.iCloudFull).isRetryable, isFalse);
    expect(const StorageFailure(StorageFailureKind.busy).isRetryable, isTrue);
    expect(
      const StorageFailure(StorageFailureKind.constraintViolated).isRetryable,
      isFalse,
    );
  });

  test('a limit failure knows how many items must be archived', () {
    const atLimit = LimitReachedFailure(count: 25, limit: 25, planName: 'base');
    const over = LimitReachedFailure(count: 40, limit: 25, planName: 'base');
    expect(atLimit.toArchive, 1);
    expect(over.toArchive, 16);
  });
}
