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
sealed class ViewState<T> {
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
final class ViewIdle<T> extends ViewState<T> {
  const ViewIdle();
}

/// Work in progress. [previous] keeps the last data on screen during a
/// refresh so lists don't flash empty.
final class ViewLoading<T> extends ViewState<T> {
  const ViewLoading({this.previous});

  final T? previous;
}

final class ViewReady<T> extends ViewState<T> {
  const ViewReady(this.data);

  final T data;
}

/// The last attempt failed. [previous] is the last good data, if any.
final class ViewFailed<T> extends ViewState<T> {
  const ViewFailed(this.failure, {this.previous});

  final AppFailure failure;
  final T? previous;
}
