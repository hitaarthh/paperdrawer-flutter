import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrawer/core/failure/app_failure.dart';
import 'package:paperdrawer/core/logging/app_logger.dart';
import 'package:paperdrawer/core/result/result.dart';
import 'package:paperdrawer/data/drawer/drawer_paths.dart';
import 'package:paperdrawer/data/purchases/sync_coordinator_plan_sync.dart';
import 'package:paperdrawer/data/sync/sync_coordinator.dart';
import 'package:paperdrawer/domain/account/account_scope.dart';
import 'package:paperdrawer/domain/plans/active_plan.dart';
import 'package:paperdrawer/domain/plans/entitlement.dart';
import 'package:paperdrawer/domain/plans/plan.dart';
import 'package:paperdrawer/domain/sync/sync_status.dart';
import 'package:paperdrawer/domain/sync/sync_transport.dart';

final _now = DateTime.utc(2026, 11, 25, 10);
final _clara = DrawerPaths.userScope(
  Uri.parse('https://example.supabase.co'),
  '11111111-1111-4111-8111-111111111111',
).requireValue;

final class _Transport implements SyncTransport {
  _Transport(this.kind, this.log);

  @override
  final SyncKind kind;
  final List<String> log;
  final ValueNotifier<SyncStatus> _status = ValueNotifier(const SyncOff());

  @override
  ValueListenable<SyncStatus> get status => _status;

  @override
  Future<Result<Unit>> start(UserScope scope, {bool fullUpload = false}) async {
    log.add('start ${kind.name}${fullUpload ? ' full' : ''}');
    return const Ok(unit);
  }

  @override
  Future<Result<Unit>> requestSync() async => const Ok(unit);

  @override
  Future<void> stop() async => log.add('stop ${kind.name}');

  @override
  void dispose() => _status.dispose();
}

final class _Factory implements SyncTransportFactory {
  final List<String> log = [];

  @override
  SyncTransport create(SyncKind kind) => _Transport(kind, log);
}

ActivePlan _plan(Plan plan, AccountScope scope) => ActivePlan.resolve(
  scope: scope,
  entitlements: Entitlements(
    grants: [
      if (plan != Plan.base) PlanGrant(plan: plan, store: PurchaseStore.appStore),
    ],
    verifiedAt: _now,
  ),
  now: _now,
);

void main() {
  late _Factory factory;
  late SyncCoordinator coordinator;
  late Plan accountPlan;
  late SyncCoordinatorPlanSync sync;

  setUp(() {
    factory = _Factory();
    coordinator = SyncCoordinator(factory: factory, logger: MemoryLogger());
    accountPlan = Plan.essential;
    sync = SyncCoordinatorPlanSync(
      coordinator: coordinator,
      activePlanFor: (scope) async => Ok(_plan(accountPlan, scope)),
    );
  });

  tearDown(() => coordinator.dispose());

  test('starts the plan transport with a full upload', () async {
    expect(await sync.startWithFullUpload(_clara, SyncKind.iCloud), const Ok(unit));
    expect(factory.log, ['start iCloud full']);
    expect(coordinator.activeKind, SyncKind.iCloud);
  });

  test('stopping drains the running transport', () async {
    await sync.startWithFullUpload(_clara, SyncKind.iCloud);
    expect(await sync.stop(SyncKind.iCloud), const Ok(unit));
    expect(factory.log.last, 'stop iCloud');
    expect(coordinator.activeKind, SyncKind.none);
  });

  test('stopping a transport that is not running does nothing', () async {
    await sync.startWithFullUpload(_clara, SyncKind.iCloud);
    expect(await sync.stop(SyncKind.paperDrawerCloud), const Ok(unit));
    expect(factory.log, ['start iCloud full']);
  });

  test("refuses to start a sync the account's plan doesn't have", () async {
    accountPlan = Plan.base;
    final result = await sync.startWithFullUpload(_clara, SyncKind.iCloud);
    expect(result.failureOrNull, isA<UnexpectedFailure>());
    expect(factory.log, isEmpty);
  });

  test('passes on a failed plan lookup', () async {
    final failing = SyncCoordinatorPlanSync(
      coordinator: coordinator,
      activePlanFor: (_) async =>
          const Err(StorageFailure(StorageFailureKind.unreadable)),
    );
    final result = await failing.startWithFullUpload(_clara, SyncKind.iCloud);
    expect(
      result.failureOrNull,
      const StorageFailure(StorageFailureKind.unreadable),
    );
  });
}
