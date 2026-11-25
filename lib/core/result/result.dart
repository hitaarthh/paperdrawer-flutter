import 'package:flutter/foundation.dart';

import '../failure/app_failure.dart';

/// The outcome of an operation that can fail in an expected way.
///
/// In generic code, write `Err<T>(failure)` with the type argument. A bare
/// `const Err(failure)` in a `Result<T>` context becomes `Err<Never>` because
/// constants can't capture type parameters.
///
/// Every repository, use case and command in PaperDrawer returns a [Result]
/// instead of throwing. Exceptions are reserved for programmer errors (a
/// broken invariant, a bug). Expected failures (validation, a full disk, no
/// network, the Base limit) travel as an [Err] holding an [AppFailure], so the
/// compiler forces every caller to handle them.
///
/// ```dart
/// final result = await items.create(draft);
/// switch (result) {
///   case Ok(:final value): open(value.id);
///   case Err(:final failure): show(failure.userMessage);
/// }
/// ```
@immutable
sealed class Result<T> {
  const Result();

  /// Wraps [value] as a success.
  const factory Result.ok(T value) = Ok<T>;

  /// Wraps [failure] as an expected failure.
  const factory Result.err(AppFailure failure) = Err<T>;

  bool get isOk => this is Ok<T>;
  bool get isErr => this is Err<T>;

  /// The value, or `null` on failure.
  T? get valueOrNull => switch (this) {
    Ok(:final value) => value,
    Err() => null,
  };

  /// The failure, or `null` on success.
  AppFailure? get failureOrNull => switch (this) {
    Ok() => null,
    Err(:final failure) => failure,
  };

  /// Returns the value or throws a [StateError].
  ///
  /// Only for tests and for code paths that have already checked [isOk].
  T get requireValue => switch (this) {
    Ok(:final value) => value,
    Err(:final failure) => throw StateError(
      'requireValue on Err: ${failure.debugDescription}',
    ),
  };

  /// Transforms the value of a success; a failure passes through unchanged.
  Result<R> map<R>(R Function(T value) transform) => switch (this) {
    Ok(:final value) => Ok(transform(value)),
    Err(:final failure) => Err(failure),
  };

  /// Chains another fallible step after a success.
  Result<R> flatMap<R>(Result<R> Function(T value) next) => switch (this) {
    Ok(:final value) => next(value),
    Err(:final failure) => Err(failure),
  };

  /// Async version of [flatMap].
  Future<Result<R>> andThen<R>(Future<Result<R>> Function(T value) next) async =>
      switch (this) {
        Ok(:final value) => await next(value),
        Err(:final failure) => Err(failure),
      };

  /// Collapses both branches into one value.
  R fold<R>({
    required R Function(T value) ok,
    required R Function(AppFailure failure) err,
  }) => switch (this) {
    Ok(:final value) => ok(value),
    Err(:final failure) => err(failure),
  };
}

/// A successful [Result].
final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;

  @override
  bool operator ==(Object other) => other is Ok && other.value == value;

  @override
  int get hashCode => Object.hash(Ok, value);

  @override
  String toString() => 'Ok($value)';
}

/// A failed [Result]. The [failure] says what went wrong and what to tell the
/// user.
final class Err<T> extends Result<T> {
  const Err(this.failure);

  final AppFailure failure;

  @override
  bool operator ==(Object other) => other is Err && other.failure == failure;

  @override
  int get hashCode => Object.hash(Err, failure);

  @override
  String toString() => 'Err(${failure.debugDescription})';
}

/// The value of a [Result] that carries no data.
///
/// Use `Result<Unit>` instead of `Result<void>` so `Ok(unit)` can be compared
/// in tests.
@immutable
final class Unit {
  const Unit._();

  @override
  String toString() => 'unit';
}

/// The single [Unit] value.
const unit = Unit._();
