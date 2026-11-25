import 'package:flutter/foundation.dart';

import '../failure/app_failure.dart';

/// What a screen is showing. Every screen renders all four cases; the
/// `switch` over this sealed type makes forgetting one a compile error.
///
/// ```dart
/// return switch (vm.state) {
///   ViewIdle() || ViewLoading() => const PdLoading(),
///   ViewReady(:final data) => VaultList(data),
///   ViewFailed(:final failure, :final previous) => previous == null
///       ? PdErrorState(failure, onRetry: vm.reload)
///       : VaultList(previous, banner: failure),
/// };
/// ```
@immutable
sealed class ViewState<T extends Object> {
  const ViewState();

  /// The data to show, if any (a failed refresh can keep the last good data).
  T? get dataOrNull => switch (this) {
    ViewReady(:final data) => data,
    ViewFailed(:final previous) => previous,
    ViewLoading(:final previous) => previous,
    ViewIdle() => null,
  };

  bool get isLoading => this is ViewLoading<T>;
}

/// Nothing requested yet.
final class ViewIdle<T extends Object> extends ViewState<T> {
  const ViewIdle();

  @override
  bool operator ==(Object other) => other is ViewIdle;

  @override
  int get hashCode => (ViewIdle).hashCode;
}

/// Work in progress. [previous] keeps the last data on screen during a
/// refresh so lists don't flash empty.
final class ViewLoading<T extends Object> extends ViewState<T> {
  const ViewLoading({this.previous});

  final T? previous;

  @override
  bool operator ==(Object other) =>
      other is ViewLoading && other.previous == previous;

  @override
  int get hashCode => Object.hash(ViewLoading, previous);
}

final class ViewReady<T extends Object> extends ViewState<T> {
  const ViewReady(this.data);

  final T data;

  @override
  bool operator ==(Object other) => other is ViewReady && other.data == data;

  @override
  int get hashCode => Object.hash(ViewReady, data);
}

/// The last attempt failed. [previous] is the last good data, if any.
final class ViewFailed<T extends Object> extends ViewState<T> {
  const ViewFailed(this.failure, {this.previous});

  final AppFailure failure;
  final T? previous;

  @override
  bool operator ==(Object other) =>
      other is ViewFailed &&
      other.failure == failure &&
      other.previous == previous;

  @override
  int get hashCode => Object.hash(failure, previous);
}
