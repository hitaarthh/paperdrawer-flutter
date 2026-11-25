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

  test('timeouts become retryable network failures', () {
    final failure = mapper.map(TimeoutException('slow'), trace);
    expect(failure, isA<NetworkFailure>());
    expect((failure as NetworkFailure).timedOut, isTrue);
    expect(failure.isRetryable, isTrue);
  });

  test('socket errors become network failures', () {
    expect(
      mapper.map(const SocketException('no route'), trace),
      isA<NetworkFailure>(),
    );
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
  });
}
