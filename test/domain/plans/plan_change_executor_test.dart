import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrawer/core/failure/app_failure.dart';
import 'package:paperdrawer/core/failure/failure_mapper.dart';
import 'package:paperdrawer/core/logging/app_logger.dart';
import 'package:paperdrawer/core/result/result.dart';
import 'package:paperdrawer/domain/account/account_scope.dart';
import 'package:paperdrawer/domain/account/auth_session.dart';
import 'package:paperdrawer/domain/plans/plan.dart';
import 'package:paperdrawer/domain/plans/plan_change.dart';
import 'package:paperdrawer/domain/plans/plan_change_executor.dart';
import 'package:paperdrawer/domain/plans/plan_change_ports.dart';

const _projectKey = 'aHR0cHM6Ly9leGFtcGxlLnN1cGFiYXNlLmNv';
const _userId = '6f1c2a3b-4d5e-4f60-8a7b-9c0d1e2f3a4b';

UserScope _user() =>
    UserScope.parse(projectKey: _projectKey, userId: _userId).requireValue;

/// The phone's drawers: what must never shrink.
final class _Drawers {
  final List<String> guest = ['bill-1', 'bill-2', 'policy-1'];
  final List<String> account = [];
  final Set<String> movedMarkers = {};
}

final class _Ports
    implements SignInPrompt, MoveGuestItemsPrompt, PlanSync, WebsiteNotifier {
  _Ports(this.drawers);

  final _Drawers drawers;
  final List<String> log = [];
  final Map<String, Result<Unit>> failAt = {};
  Result<AuthSession>? signInResult;
  bool declineMove = false;
  String? throwAt;

  Result<Unit> _outcome(String call) {
    log.add(call);
    if (throwAt == call) throw StateError('port crashed');
    return failAt[call] ?? const Ok(unit);
  }

  @override
  Future<Result<AuthSession>> signIn(Set<SignInMethod> methods) async {
    log.add('signIn ${methods.map((m) => m.name).join('+')}');
    return signInResult ??
        AuthSession.create(projectKey: _projectKey, userId: _userId);
  }

  @override
  Future<Result<MoveGuestItemsChoice>> offer({required UserScope into}) async {
    final outcome = _outcome('offerMove');
    if (outcome case Err(:final failure)) {
      return Err<MoveGuestItemsChoice>(failure);
    }
    if (declineMove) return const Ok(MoveGuestItemsChoice.kept);
    // Copy and mark: the guest rows stay.
    drawers.account.addAll(drawers.guest);
    drawers.movedMarkers.addAll(drawers.guest);
    return const Ok(MoveGuestItemsChoice.moved);
  }

  @override
  Future<Result<Unit>> stop(SyncKind kind) async => _outcome('stop ${kind.name}');

  @override
  Future<Result<Unit>> startWithFullUpload(
    UserScope scope,
    SyncKind kind,
  ) async => _outcome('start ${kind.name}');

  @override
  Future<Result<Unit>> websiteBecomesReadOnly(UserScope scope) async =>
      _outcome('websiteReadOnly');
}

void main() {
  late _Drawers drawers;
  late _Ports ports;
  late MemoryLogger logger;
  late PlanChangeExecutor executor;

  setUp(() {
    drawers = _Drawers();
    ports = _Ports(drawers);
    logger = MemoryLogger();
    executor = PlanChangeExecutor(
      signIn: ports,
      moveGuestItems: ports,
      sync: ports,
      website: ports,
      logger: logger,
      failures: FailureMapper(),
    );
  });

  Future<Result<PlanChangeOutcome>> run(
    Plan from,
    Plan to, {
    required AccountScope scope,
  }) => executor(
    PlanChangeRequest(
      change: PlanChange.between(from, to, isGuest: scope.isGuest),
      scope: scope,
    ),
  );

  void expectNothingDeleted() {
    expect(drawers.guest, ['bill-1', 'bill-2', 'policy-1']);
  }

  test('guest Base → Essential: Apple sign-in, move, iCloud upload', () async {
    final result = await run(Plan.base, Plan.essential, scope: const GuestScope());

    expect(ports.log, ['signIn apple', 'offerMove', 'start iCloud']);
    final outcome = result.requireValue;
    expect(outcome.scope, _user());
    expect(outcome.guestItems, MoveGuestItemsChoice.moved);
    expect(outcome.completed, hasLength(3));
    expect(drawers.account, drawers.guest);
    expectNothingDeleted();
  });

  test('saying no to moving keeps the items in the guest drawer', () async {
    ports.declineMove = true;
    final result = await run(Plan.base, Plan.pro, scope: const GuestScope());

    expect(result.requireValue.guestItems, MoveGuestItemsChoice.kept);
    expect(drawers.account, isEmpty);
    expectNothingDeleted();
    expect(ports.log.last, 'start paperDrawerCloud');
  });

  test('cancelled sign-in stops before anything else runs', () async {
    ports.signInResult = const Err(AuthFailure(AuthFailureKind.cancelled));
    final result = await run(Plan.base, Plan.essential, scope: const GuestScope());

    expect(result, const Err<PlanChangeOutcome>(AuthFailure(AuthFailureKind.cancelled)));
    expect(ports.log, ['signIn apple']);
    expect(drawers.account, isEmpty);
    expectNothingDeleted();
  });

  test('a failed upload stops the change and keeps every item', () async {
    ports.failAt['start iCloud'] = const Err(
      SyncFailure(SyncPauseReason.iCloudUnavailable),
    );
    final result = await run(Plan.base, Plan.essential, scope: const GuestScope());

    expect(
      result.failureOrNull,
      const SyncFailure(SyncPauseReason.iCloudUnavailable),
    );
    expectNothingDeleted();
    expect(drawers.account, drawers.guest, reason: 'moved copies stay');
    expect(
      logger.entries.single.$2,
      contains('step 3/3 (StartSyncWithFullUpload)'),
    );
  });

  test('a failed move stops before sync starts', () async {
    ports.failAt['offerMove'] = const Err(StorageFailure(StorageFailureKind.full));
    final result = await run(Plan.base, Plan.pro, scope: const GuestScope());

    expect(result.failureOrNull, const StorageFailure(StorageFailureKind.full));
    expect(ports.log, ['signIn apple+email', 'offerMove']);
    expectNothingDeleted();
  });

  test('Essential → Pro stops iCloud before the cloud upload', () async {
    final result = await run(Plan.essential, Plan.pro, scope: _user());

    expect(result.isOk, isTrue);
    expect(ports.log, ['stop iCloud', 'start paperDrawerCloud']);
  });

  test('Pro ending with Essential owned: stop, iCloud upload, website read-only',
      () async {
    await run(Plan.pro, Plan.essential, scope: _user());

    expect(ports.log, [
      'stop paperDrawerCloud',
      'start iCloud',
      'websiteReadOnly',
    ]);
  });

  test('stop failing leaves the next transport unstarted', () async {
    ports.failAt['stop paperDrawerCloud'] = const Err(NetworkFailure());
    final result = await run(Plan.pro, Plan.essential, scope: _user());

    expect(result.failureOrNull, const NetworkFailure());
    expect(ports.log, ['stop paperDrawerCloud']);
  });

  test('Essential refunded: back to Base, sync stops, nothing deleted', () async {
    final result = await run(Plan.essential, Plan.base, scope: _user());

    expect(ports.log, ['stop iCloud']);
    expect(result.requireValue.scope, _user());
    expectNothingDeleted();
  });

  test('a port that throws becomes an Err, not a crash', () async {
    ports.throwAt = 'stop iCloud';
    final result = await run(Plan.essential, Plan.pro, scope: _user());

    expect(result.failureOrNull, isA<UnexpectedFailure>());
    expect(ports.log, ['stop iCloud']);
  });

  test('finishing setup after a guest purchase moves and uploads', () async {
    final result = await executor(
      PlanChangeRequest(
        change: PlanChange.finishAccountSetup(Plan.essential),
        scope: _user(),
      ),
    );

    expect(result.isOk, isTrue);
    expect(ports.log, ['offerMove', 'start iCloud']);
  });

  test('a step needing an account fails safely while still a guest', () async {
    final result = await executor(
      PlanChangeRequest(
        change: PlanChange.finishAccountSetup(Plan.pro),
        scope: const GuestScope(),
      ),
    );

    expect(result.failureOrNull, isA<UnexpectedFailure>());
    expect(ports.log, isEmpty);
    expectNothingDeleted();
  });

  test('an already signed-in user is not asked to sign in again', () async {
    // A retry after a failed upload: the change is rebuilt for a guest but
    // the drawer is now the account's.
    final result = await executor(
      PlanChangeRequest(
        change: PlanChange.between(Plan.base, Plan.essential, isGuest: true),
        scope: _user(),
      ),
    );

    expect(result.isOk, isTrue);
    expect(ports.log, ['offerMove', 'start iCloud']);
  });

  test('no change runs no steps', () async {
    final result = await run(Plan.pro, Plan.pro, scope: _user());

    expect(result.requireValue.completed, isEmpty);
    expect(ports.log, isEmpty);
  });
}
