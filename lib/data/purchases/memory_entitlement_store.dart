import '../../core/failure/app_failure.dart';
import '../../core/result/result.dart';
import '../../domain/plans/entitlement.dart';
import '../../domain/plans/entitlement_store.dart';

/// [EntitlementStore] in memory, for tests and the simulator until the
/// SQLite store lands (wave 2). Inject a failure with [failNextWith].
final class MemoryEntitlementStore implements EntitlementStore {
  MemoryEntitlementStore([this._saved]);

  Entitlements? _saved;

  /// The next call fails with this, once.
  AppFailure? failNextWith;

  Entitlements? get saved => _saved;

  @override
  Future<Result<Entitlements?>> load() async {
    final failure = _takeFailure();
    if (failure != null) return Err<Entitlements?>(failure);
    return Ok(_saved);
  }

  @override
  Future<Result<Unit>> save(Entitlements entitlements) async {
    final failure = _takeFailure();
    if (failure != null) return Err<Unit>(failure);
    _saved = entitlements;
    return const Ok(unit);
  }

  AppFailure? _takeFailure() {
    final failure = failNextWith;
    failNextWith = null;
    return failure;
  }
}
