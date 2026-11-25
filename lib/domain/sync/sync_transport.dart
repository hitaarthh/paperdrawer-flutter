import 'package:flutter/foundation.dart';

import '../../core/result/result.dart';
import '../account/account_scope.dart';
import '../plans/plan.dart';
import 'sync_status.dart';

/// How the vault travels between this phone and one cloud.
///
/// Three implementations, one per [SyncKind]:
/// - `NoSyncTransport` (Base) — does nothing, always [SyncOff];
/// - `CloudKitSyncTransport` (Essential) — calls the Swift CKSyncEngine
///   plugin;
/// - `SupabaseSyncTransport` (Pro) — uploads the outbox, pulls changes,
///   merges field by field.
///
/// Contract every implementation must keep (tests in
/// test/domain/sync/sync_transport_contract.dart run against each one):
/// - The phone's database is always the main copy. A transport only reads
///   dirty rows and applies merged remote changes; it never deletes local
///   rows except to apply a remote delete marker.
/// - [start] is bound to one [UserScope]. Results that arrive after [stop]
///   are dropped, so nothing lands in another account's drawer.
/// - Methods return [Result]s and never throw.
/// - [stop] lets the current upload finish, then returns. Calling it twice
///   is safe.
abstract interface class SyncTransport {
  SyncKind get kind;

  /// The current status, for the Settings row and the banner.
  ValueListenable<SyncStatus> get status;

  /// Starts syncing [scope]'s drawer. With [fullUpload], every record is
  /// uploaded first (after an upgrade or a transport switch).
  Future<Result<Unit>> start(UserScope scope, {bool fullUpload = false});

  /// Asks for a sync soon (after a local write, on foreground).
  Future<Result<Unit>> requestSync();

  /// Finishes the current upload and stops.
  Future<void> stop();
}

/// Creates the transport for a [SyncKind] (factory). The composition root
/// provides the real one; tests provide fakes.
abstract interface class SyncTransportFactory {
  SyncTransport create(SyncKind kind);
}
