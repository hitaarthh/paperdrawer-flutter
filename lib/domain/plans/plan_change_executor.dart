import 'package:flutter/foundation.dart';

import '../../core/domain/use_case.dart';
import '../../core/failure/app_failure.dart';
import '../../core/failure/failure_mapper.dart';
import '../../core/logging/app_logger.dart';
import '../../core/result/result.dart';
import '../account/account_scope.dart';
import 'plan_change.dart';
import 'plan_change_ports.dart';

/// A [PlanChange] to carry out for the drawer open now ([scope]).
@immutable
final class PlanChangeRequest {
  const PlanChangeRequest({required this.change, required this.scope});

  final PlanChange change;

  /// The open drawer when the change starts. A guest becomes a user after a
  /// `RequireSignIn` step.
  final AccountScope scope;

  @override
  bool operator ==(Object other) =>
      other is PlanChangeRequest &&
      other.change == change &&
      other.scope == scope;

  @override
  int get hashCode => Object.hash(change, scope);
}

/// What a completed plan change did.
@immutable
final class PlanChangeOutcome {
  PlanChangeOutcome({
    required this.scope,
    required List<PlanChangeStep> completed,
    this.guestItems,
  }) : completed = List.unmodifiable(completed);

  /// The drawer open at the end (the account's, after a sign-in).
  final AccountScope scope;

  /// Every step, in order. All of them ran.
  final List<PlanChangeStep> completed;

  /// The answer to "Move these items into your account?", when asked.
  final MoveGuestItemsChoice? guestItems;

  @override
  bool operator ==(Object other) =>
      other is PlanChangeOutcome &&
      other.scope == scope &&
      listEquals(other.completed, completed) &&
      other.guestItems == guestItems;

  @override
  int get hashCode =>
      Object.hash(scope, Object.hashAll(completed), guestItems);
}

/// Runs a [PlanChange]'s steps, in order, through ports.
///
/// Guarantees:
/// - Stops at the first `Err` and returns it; later steps don't run.
///   Running the same change again is safe: sign-in is skipped once signed
///   in, moving is idempotent, stop is a no-op when stopped, and a full
///   upload merges.
/// - Never deletes local data: [PlanChangeStep] has no such step and none of
///   the ports can delete.
/// - Never throws: a port that throws becomes an `Err` through the
///   [FailureMapper].
///
/// Failure cases: whatever the failing step's port returns (see
/// `plan_change_ports.dart`), and `UnexpectedFailure` when a step needs an
/// account but the drawer is still the guest's (a broken change).
final class PlanChangeExecutor
    implements UseCase<PlanChangeRequest, PlanChangeOutcome> {
  PlanChangeExecutor({
    required SignInPrompt signIn,
    required MoveGuestItemsPrompt moveGuestItems,
    required PlanSync sync,
    required WebsiteNotifier website,
    required AppLogger logger,
    required FailureMapper failures,
  }) : _signIn = signIn,
       _moveGuestItems = moveGuestItems,
       _sync = sync,
       _website = website,
       _logger = logger,
       _failures = failures;

  final SignInPrompt _signIn;
  final MoveGuestItemsPrompt _moveGuestItems;
  final PlanSync _sync;
  final WebsiteNotifier _website;
  final AppLogger _logger;
  final FailureMapper _failures;

  @override
  Future<Result<PlanChangeOutcome>> call(PlanChangeRequest input) async {
    var progress = _Progress(input.scope);
    final steps = input.change.steps;
    for (var index = 0; index < steps.length; index++) {
      final step = steps[index];
      final result = await _guard(() => _run(step, progress));
      switch (result) {
        case Ok(:final value):
          progress = value;
        case Err(:final failure):
          _logger.failure(
            'PlanChangeExecutor step ${index + 1}/${steps.length} '
            '(${step.runtimeType})',
            failure,
          );
          return Err<PlanChangeOutcome>(failure);
      }
    }
    _logger.info('PlanChangeExecutor: ${steps.length} steps done');
    return Ok(
      PlanChangeOutcome(
        scope: progress.scope,
        completed: steps,
        guestItems: progress.guestItems,
      ),
    );
  }

  Future<Result<_Progress>> _run(PlanChangeStep step, _Progress progress) async {
    switch (step) {
      case RequireSignIn(:final methods):
        if (progress.scope is UserScope) return Ok(progress);
        final session = await _signIn.signIn(methods);
        return session.map((value) => progress.withScope(value.scope));
      case OfferMoveGuestItems():
        return _forUser(progress, (user) async {
          final choice = await _moveGuestItems.offer(into: user);
          return choice.map(progress.withGuestItems);
        });
      case StopSync(:final kind):
        final stopped = await _sync.stop(kind);
        return stopped.map((_) => progress);
      case StartSyncWithFullUpload(:final kind):
        return _forUser(progress, (user) async {
          final started = await _sync.startWithFullUpload(user, kind);
          return started.map((_) => progress);
        });
      case WebsiteBecomesReadOnly():
        return _forUser(progress, (user) async {
          final told = await _website.websiteBecomesReadOnly(user);
          return told.map((_) => progress);
        });
    }
  }

  Future<Result<_Progress>> _forUser(
    _Progress progress,
    Future<Result<_Progress>> Function(UserScope user) run,
  ) async => switch (progress.scope) {
    final UserScope user => await run(user),
    GuestScope() => Err<_Progress>(
      UnexpectedFailure(
        cause: StateError('plan change step needs an account'),
      ),
    ),
  };

  Future<Result<T>> _guard<T>(Future<Result<T>> Function() body) async {
    try {
      return await body();
    } catch (error, stackTrace) {
      return Err<T>(_failures.map(error, stackTrace));
    }
  }
}

@immutable
final class _Progress {
  const _Progress(this.scope, {this.guestItems});

  final AccountScope scope;
  final MoveGuestItemsChoice? guestItems;

  _Progress withScope(AccountScope value) =>
      _Progress(value, guestItems: guestItems);

  _Progress withGuestItems(MoveGuestItemsChoice value) =>
      _Progress(scope, guestItems: value);
}
