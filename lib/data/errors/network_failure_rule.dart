import 'dart:async';
import 'dart:io';

import '../../core/failure/app_failure.dart';
import '../../core/failure/failure_mapper.dart';

/// Maps network errors to [NetworkFailure]. Use it only in mappers for
/// network adapters (Supabase, purchases): a local timeout is not "no
/// internet".
final class NetworkFailureRule implements FailureRule {
  const NetworkFailureRule();

  @override
  AppFailure? tryMap(Object error, StackTrace stackTrace) => switch (error) {
    TimeoutException() => NetworkFailure(
      timedOut: true,
      cause: error,
      stackTrace: stackTrace,
    ),
    SocketException() || HttpException() || HandshakeException() =>
      NetworkFailure(cause: error, stackTrace: stackTrace),
    _ => null,
  };
}
