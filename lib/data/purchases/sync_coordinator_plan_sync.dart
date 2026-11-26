import '../../core/failure/app_failure.dart';
import '../../core/result/result.dart';
import '../../domain/account/account_scope.dart';
import '../../domain/plans/active_plan.dart';
import '../../domain/plans/plan.dart';
import '../../domain/plans/plan_change_ports.dart';
import '../sync/sync_coordinator.dart';

/// Resolves the plan of [scope]'s drawer from its saved entitlements (the
/// composition root knows the open drawer and its `EntitlementStore`).
typedef ActivePlanLookup = Future<Result<ActivePlan>> Function(UserScope scope);

/// [PlanSync] over the one [SyncCoordinator] (adapter).
///
/// Lives here until `SyncCoordinator` can implement [PlanSync] itself (its
/// owner's call).
final class SyncCoordinatorPlanSync implements PlanSync {
  SyncCoordinatorPlanSync({
    required SyncCoordinator coordinator,
    required ActivePlanLookup activePlanFor,
  }) : _coordinator = coordinator,
       _activePlanFor = activePlanFor;

  final SyncCoordinator _coordinator;
  final ActivePlanLookup _activePlanFor;

  @override
  Future<Result<Unit>> stop(SyncKind kind) async {
    if (_coordinator.activeKind != kind) return const Ok(unit);
    // deactivate() drains the transport (push, pull once more) before it
    // stops. Local data is untouched.
    await _coordinator.deactivate();
    return const Ok(unit);
  }

  @override
  Future<Result<Unit>> startWithFullUpload(
    UserScope scope,
    SyncKind kind,
  ) async {
    final plan = await _activePlanFor(scope);
    return plan.andThen((active) async {
      if (active.scope != scope || active.syncKind != kind) {
        return Err<Unit>(
          UnexpectedFailure(
            cause: StateError(
              'plan syncs ${active.syncKind.name}, not ${kind.name}',
            ),
          ),
        );
      }
      return _coordinator.activate(active, fullUpload: true);
    });
  }
}
