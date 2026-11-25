import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrawer/core/concurrency/serial_queue.dart';
import 'package:paperdrawer/core/data/repository.dart';
import 'package:paperdrawer/core/failure/app_failure.dart';
import 'package:paperdrawer/core/failure/failure_mapper.dart';
import 'package:paperdrawer/core/failure/validation_issue.dart';
import 'package:paperdrawer/core/logging/app_logger.dart';
import 'package:paperdrawer/core/result/result.dart';

/// A fake store standing in for SQLite.
class _Store {
  List<String> rows = [];
  bool failReads = false;
}

/// The smallest real subclass: a list of names.
final class _NamesRepository extends Repository<List<String>> {
  _NamesRepository(this.store, {AppLogger? logger, SerialQueue? queue})
    : super(
        name: 'names',
        failures: FailureMapper(),
        logger: logger ?? MemoryLogger(),
        queue: queue,
      );

  final _Store store;

  List<String> get names => snapshot;

  @override
  Future<List<String>> readSnapshot() async {
    if (store.failReads) throw StateError('read failed');
    return List.unmodifiable(store.rows);
  }

  Future<Result<String>> add(String name, {Completer<void>? gate}) =>
      write('add', () async {
        if (name.trim().isEmpty) {
          return const Err(ValidationFailure(ValidationIssue.nameRequired));
        }
        await gate?.future;
        store.rows = [...store.rows, name];
        return Ok(name);
      });

  Future<Result<Unit>> explode() =>
      write('explode', () async => throw StateError('disk on fire'));

  /// A bug: writing from inside a write.
  Future<Result<Unit>> nested() => write('nested', () async {
    final inner = await add('inner');
    return inner.map((_) => unit);
  });
}

void main() {
  late _Store store;
  late _NamesRepository repo;
  late int notifications;

  setUp(() async {
    store = _Store();
    repo = _NamesRepository(store);
    notifications = 0;
    repo.addListener(() => notifications++);
  });

  test('reading the snapshot before load is a programmer error', () {
    expect(() => repo.names, throwsStateError);
    expect(repo.isLoaded, isFalse);
  });

  test('load reads the snapshot and notifies', () async {
    store.rows = ['a'];
    expect(await repo.load(), const Ok(unit));
    expect(repo.names, ['a']);
    expect(notifications, 1);
  });

  test('a successful write refreshes the snapshot and notifies once', () async {
    await repo.load();
    notifications = 0;
    expect(await repo.add('bill'), const Ok('bill'));
    expect(repo.names, ['bill']);
    expect(notifications, 1);
  });

  test('an Err write changes nothing and does not notify', () async {
    await repo.load();
    notifications = 0;
    final result = await repo.add('  ');
    expect(
      result,
      const Err<String>(ValidationFailure(ValidationIssue.nameRequired)),
    );
    expect(repo.names, isEmpty);
    expect(notifications, 0);
  });

  test('a thrown error becomes an Err and is logged by type only', () async {
    final logger = MemoryLogger();
    repo = _NamesRepository(store, logger: logger);
    await repo.load();
    final result = await repo.explode();
    expect(result.failureOrNull, isA<UnexpectedFailure>());
    final line = logger.entries.single.$2;
    expect(line, contains('names.explode'));
    expect(line, isNot(contains('disk on fire')));
  });

  test('writes are serialized', () async {
    await repo.load();
    final gate = Completer<void>();
    final first = repo.add('first', gate: gate);
    final second = repo.add('second');
    await Future<void>.delayed(Duration.zero);
    expect(store.rows, isEmpty, reason: 'second must wait for first');
    gate.complete();
    await Future.wait([first, second]);
    expect(repo.names, ['first', 'second']);
  });

  test('repositories sharing a queue never interleave', () async {
    final queue = SerialQueue();
    final a = _NamesRepository(store, queue: queue);
    final otherStore = _Store();
    final b = _NamesRepository(otherStore, queue: queue);
    await a.load();
    await b.load();
    final gate = Completer<void>();
    final first = a.add('a', gate: gate);
    final second = b.add('b');
    await Future<void>.delayed(Duration.zero);
    expect(otherStore.rows, isEmpty);
    gate.complete();
    await Future.wait([first, second]);
    expect(otherStore.rows, ['b']);
  });

  test('a failed refresh after a committed write still reports Ok', () async {
    await repo.load();
    store.failReads = true;
    final result = await repo.add('kept');
    expect(result, const Ok('kept'), reason: 'retrying would duplicate it');
    expect(store.rows, ['kept']);
    expect(repo.isStale, isTrue);

    store.failReads = false;
    await repo.load();
    expect(repo.isStale, isFalse);
    expect(repo.names, ['kept']);
  });

  test('a write from inside a write is reported as a bug, not a hang',
      () async {
    await repo.load();
    // Asserts are on in tests; the nested call trips one inside the queue,
    // which the outer write turns into an Err.
    final result = await repo.nested().timeout(const Duration(seconds: 2));
    expect(result.isErr, isTrue);
  });

  test('close lets queued writes finish, then refuses new ones', () async {
    await repo.load();
    final gate = Completer<void>();
    final queued = repo.add('before close', gate: gate);
    final closing = repo.close();
    final afterClose = await repo.add('after close');
    expect(afterClose, const Err<String>(ScopeClosedFailure()));

    gate.complete();
    await closing;
    expect(await queued, const Ok('before close'));
    expect(store.rows, ['before close']);
  });

  test('a second close also waits for queued writes', () async {
    await repo.load();
    final gate = Completer<void>();
    final queued = repo.add('x', gate: gate);
    unawaited(repo.close());
    var secondDone = false;
    unawaited(repo.close().then((_) => secondDone = true));
    await Future<void>.delayed(Duration.zero);
    expect(secondDone, isFalse);
    gate.complete();
    await queued;
    await Future<void>.delayed(Duration.zero);
    expect(secondDone, isTrue);
  });

  test('no notifications once disposed, even for work already queued',
      () async {
    await repo.load();
    final gate = Completer<void>();
    final queued = repo.add('late', gate: gate);
    final countBefore = notifications;
    // dispose() also closes, so the queued write still finishes safely.
    repo.dispose();
    gate.complete();
    expect(await queued, const Ok('late'));
    expect(notifications, countBefore);
    expect(await repo.add('x'), const Err<String>(ScopeClosedFailure()));
  });
}
