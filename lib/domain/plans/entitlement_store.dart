import '../../core/result/result.dart';
import 'entitlement.dart';

/// Saved entitlements of the open drawer's account (port).
///
/// Lives in the account's own database so the plan resolves offline at
/// startup (`ActivePlan.resolve`). The SQLite implementation comes with the
/// data layer (wave 2); `MemoryEntitlementStore` serves tests until then.
///
/// One store is bound to one drawer: switching accounts switches stores.
abstract interface class EntitlementStore {
  /// The saved entitlements, or `Ok(null)` when none were ever saved.
  ///
  /// Failure cases: `StorageFailure` (unreadable, corrupt),
  /// `ScopeClosedFailure` (the drawer was closed).
  Future<Result<Entitlements?>> load();

  /// Replaces the saved entitlements.
  ///
  /// Failure cases: `StorageFailure` (full, busy, writeFailed),
  /// `ScopeClosedFailure` (the drawer was closed).
  Future<Result<Unit>> save(Entitlements entitlements);
}
