import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrawer/core/failure/app_failure.dart';
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
  _FakeTransport(this.kind, this.log, {this.startResult, this.throwOnStart = false});

  @override
  final SyncKind kind;
  final List<String> log;
  final Result<Unit>? startResult;
  final bool throwOnStart;
  final ValueNotifier<SyncStatus> _status = ValueNotifier(const SyncIdle());
  bool running = false;
  bool disposed = false;

  @override
  ValueListenable<SyncStatus> get status => _status;

  @override
  Future<Result<Unit>> start(UserScope scope, {bool fullUpload = false}) async {
    if (throwOnStart) throw StateError('plugin crashed');
    log.add(
      'start ${kind.name} ${scope.id.substring(0, 4)}${fullUpload ? ' full' : ''}',
    );
    final result = startResult ?? const Ok(unit);
    running = result.isOk;
    return result;
  }

  @override
  Future<Result<Unit>> requestSync() async => const Ok(unit);

  @override
  Future<void> stop() async {
    if (running) log.add('stop ${kind.name}');
    running = false;
  }

  @override
  void dispose() {
    disposed = true;
    _status.dispose();
  }

  void report(SyncStatus status) => _status.value = status;
}

final class _FakeFactory implements SyncTransportFactory {
  final List<String> log = [];
  final List<_FakeTransport> created = [];
  Result<Unit>? nextStartResult;
  bool nextThrows = false;

  @override
  SyncTransport create(SyncKind kind) {
    final transport = _FakeTransport(
      kind,
      log,
      startResult: nextStartResult,
      throwOnStart: nextThrows,
    );
    nextStartResult = null;
    nextThrows = false;
    created.add(transport);
    return transport;
  }
}

void main() {
  syncTransportContract('NoSyncTransport', NoSyncTransport.new);

  final now = DateTime.utc(2026, 12, 1);
  UserScope user(String prefix) => UserScope.parse(
    projectKey: 'cHJvamVjdA',
    userId: '${prefix}1a52-6c1e-4b8e-9d55-0d7c3b7f9a10',
  ).requireValue;
  final clara = user('aaaa');
  final john = user('bbbb');

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
    await coordinator.activate(planFor(const GuestScope(), Plan.base));
    expect(coordinator.activeKind, SyncKind.none);
    expect(factory.log, isEmpty);
    expect(coordinator.status.value, const SyncOff());
  });

  test('same plan and account twice starts once', () async {
    await coordinator.activate(planFor(clara, Plan.pro));
    await coordinator.activate(planFor(clara, Plan.pro));
    expect(factory.log, ['start paperDrawerCloud aaaa']);
  });

  test('switching plans stops the old transport before starting the new',
      () async {
    await coordinator.activate(planFor(clara, Plan.essential));
    await coordinator.activate(planFor(clara, Plan.pro), fullUpload: true);
    expect(factory.log, [
      'start iCloud aaaa',
      'stop iCloud',
      'start paperDrawerCloud aaaa full',
    ]);
    expect(factory.created.where((t) => t.running), hasLength(1));
    expect(factory.created.first.disposed, isTrue);
  });

  test('switching accounts gets a fresh transport for the new account',
      () async {
    await coordinator.activate(planFor(clara, Plan.pro));
    await coordinator.activate(planFor(john, Plan.pro));
    expect(factory.log, [
      'start paperDrawerCloud aaaa',
      'stop paperDrawerCloud',
      'start paperDrawerCloud bbbb',
    ]);
    expect(factory.created.first.running, isFalse);
  });

  test('a failed start is retried by the next activate', () async {
    factory.nextStartResult = const Err(SyncFailure(SyncPauseReason.offline));
    final first = await coordinator.activate(planFor(clara, Plan.pro));
    expect(first.isErr, isTrue);
    final second = await coordinator.activate(planFor(clara, Plan.pro));
    expect(second.isOk, isTrue);
    expect(factory.log.where((l) => l.startsWith('start')), hasLength(2));
  });

  test('a transport that throws leaves the coordinator usable', () async {
    factory.nextThrows = true;
    final result = await coordinator.activate(planFor(clara, Plan.pro));
    expect(result.failureOrNull, isA<UnexpectedFailure>());
    expect(coordinator.activeKind, SyncKind.none);
    expect((await coordinator.activate(planFor(clara, Plan.pro))).isOk, isTrue);
  });

  test('deactivate stops syncing and reports off', () async {
    await coordinator.activate(planFor(clara, Plan.pro));
    await coordinator.deactivate();
    expect(factory.log.last, 'stop paperDrawerCloud');
    expect(coordinator.activeKind, SyncKind.none);
    expect(coordinator.status.value, const SyncOff());
  });

  test('a guest who paid does not sync until signed in', () async {
    await coordinator.activate(planFor(const GuestScope(), Plan.essential));
    expect(factory.log, isEmpty);
  });

  test('status follows the current transport', () async {
    await coordinator.activate(planFor(clara, Plan.pro));
    factory.created.single.report(const SyncRunning(pending: 3));
    expect(coordinator.status.value, const SyncRunning(pending: 3));
  });
}
