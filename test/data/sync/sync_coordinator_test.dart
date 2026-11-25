import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrawer/core/logging/app_logger.dart';
import 'package:paperdrawer/core/result/result.dart';
import 'package:paperdrawer/data/sync/no_sync_transport.dart';
import 'package:paperdrawer/data/sync/sync_coordinator.dart';
import 'package:paperdrawer/domain/account/account_scope.dart';
import 'package:paperdrawer/domain/plans/active_plan.dart';
import 'package:paperdrawer/domain/plans/entitlement.dart';
import 'package:paperdrawer/domain/plans/plan.dart';
import 'package:paperdrawer/domain/sync/sync_status.dart';
import 'package:paperdrawer/domain/sync/sync_transport.dart';

import '../../domain/sync/sync_transport_contract.dart';

/// Records what happened to it and to every other fake, in one shared log.
final class _FakeTransport implements SyncTransport {
  _FakeTransport(this.kind, this.log);

  @override
  final SyncKind kind;
  final List<String> log;
  final ValueNotifier<SyncStatus> _status = ValueNotifier(const SyncIdle());
  bool running = false;

  @override
  ValueListenable<SyncStatus> get status => _status;

  @override
  Future<Result<Unit>> start(UserScope scope, {bool fullUpload = false}) async {
    running = true;
    log.add('start ${kind.name} ${scope.id.substring(0, 4)}${fullUpload ? ' full' : ''}');
    return const Ok(unit);
  }

  @override
  Future<Result<Unit>> requestSync() async => const Ok(unit);

  @override
  Future<void> stop() async {
    if (running) log.add('stop ${kind.name}');
    running = false;
  }

  void report(SyncStatus status) => _status.value = status;
}

final class _FakeFactory implements SyncTransportFactory {
  final List<String> log = [];
  final List<_FakeTransport> created = [];

  @override
  SyncTransport create(SyncKind kind) {
    final transport = _FakeTransport(kind, log);
    created.add(transport);
    return transport;
  }
}

void main() {
  syncTransportContract('NoSyncTransport', NoSyncTransport.new);

  final now = DateTime(2026, 12, 1);
  final clara = UserScope.parse('aaaa1a52-6c1e-4b8e-9d55-0d7c3b7f9a10').requireValue;
  final john = UserScope.parse('bbbb1a52-6c1e-4b8e-9d55-0d7c3b7f9a10').requireValue;

  ActivePlan planFor(AccountScope scope, Plan plan) => ActivePlan.resolve(
    scope: scope,
    entitlements: Entitlements(
      grants: [
        if (plan != Plan.base)
          PlanGrant(
            plan: plan,
            store: PurchaseStore.appStore,
            expiresAt: plan == Plan.pro ? now.add(const Duration(days: 30)) : null,
          ),
      ],
      verifiedAt: now,
    ),
    now: now,
  );

  late _FakeFactory factory;
  late SyncCoordinator coordinator;

  setUp(() {
    factory = _FakeFactory();
    coordinator = SyncCoordinator(factory: factory, logger: MemoryLogger());
  });

  test('Base runs nothing', () async {
    await coordinator.activate(scope: const GuestScope(), plan: planFor(const GuestScope(), Plan.base));
    expect(coordinator.activeKind, SyncKind.none);
    expect(factory.log, isEmpty);
    expect(coordinator.status.value, const SyncOff());
  });

  test('same plan and account twice starts once', () async {
    await coordinator.activate(scope: clara, plan: planFor(clara, Plan.pro));
    await coordinator.activate(scope: clara, plan: planFor(clara, Plan.pro));
    expect(factory.log, ['start paperDrawerCloud aaaa']);
  });

  test('switching plans stops the old transport before starting the new', () async {
    await coordinator.activate(scope: clara, plan: planFor(clara, Plan.essential));
    await coordinator.activate(scope: clara, plan: planFor(clara, Plan.pro), fullUpload: true);
    expect(factory.log, [
      'start iCloud aaaa',
      'stop iCloud',
      'start paperDrawerCloud aaaa full',
    ]);
    expect(factory.created.where((t) => t.running), hasLength(1));
  });

  test('switching accounts gets a fresh transport bound to the new account', () async {
    await coordinator.activate(scope: clara, plan: planFor(clara, Plan.pro));
    await coordinator.activate(scope: john, plan: planFor(john, Plan.pro));
    expect(factory.log, [
      'start paperDrawerCloud aaaa',
      'stop paperDrawerCloud',
      'start paperDrawerCloud bbbb',
    ]);
    expect(factory.created.first.running, isFalse);
  });

  test('deactivate stops syncing and reports off', () async {
    await coordinator.activate(scope: clara, plan: planFor(clara, Plan.pro));
    await coordinator.deactivate();
    expect(factory.log.last, 'stop paperDrawerCloud');
    expect(coordinator.activeKind, SyncKind.none);
    expect(coordinator.status.value, const SyncOff());
  });

  test('a guest who paid does not sync until signed in', () async {
    await coordinator.activate(
      scope: const GuestScope(),
      plan: planFor(const GuestScope(), Plan.essential),
    );
    expect(factory.log, isEmpty);
  });

  test('status follows the current transport', () async {
    await coordinator.activate(scope: clara, plan: planFor(clara, Plan.pro));
    factory.created.single.report(const SyncRunning(pending: 3));
    expect(coordinator.status.value, const SyncRunning(pending: 3));
  });
}
