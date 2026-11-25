import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrawer/core/failure/app_failure.dart';
import 'package:paperdrawer/core/failure/failure_mapper.dart';
import 'package:paperdrawer/data/errors/network_failure_rule.dart';
import 'package:paperdrawer/data/errors/sqflite_failure_rule.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  final trace = StackTrace.current;

  group('NetworkFailureRule', () {
    final mapper = FailureMapper(extraRules: const [NetworkFailureRule()]);

    test('timeouts become retryable network failures', () {
      final failure = mapper.map(TimeoutException('slow'), trace);
      expect(failure, const NetworkFailure(timedOut: true));
      expect(failure.isRetryable, isTrue);
    });

    test('socket and HTTP errors become network failures', () {
      expect(
        mapper.map(const SocketException('no route'), trace),
        const NetworkFailure(),
      );
      expect(
        mapper.map(const HttpException('reset'), trace),
        const NetworkFailure(),
      );
    });
  });

  group('SqfliteFailureRule (real SQLite)', () {
    late Database db;
    final mapper = FailureMapper(extraRules: const [SqfliteFailureRule()]);

    setUpAll(sqfliteFfiInit);

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await db.execute('CREATE TABLE t (id TEXT PRIMARY KEY, name TEXT)');
    });

    tearDown(() async {
      if (db.isOpen) await db.close();
    });

    test('a duplicate ID is a constraint violation, not a retryable error',
        () async {
      await db.insert('t', {'id': 'a', 'name': 'Samsung fridge'});
      Object? error;
      try {
        await db.insert('t', {'id': 'a', 'name': 'Samsung fridge'});
      } catch (e) {
        error = e;
      }
      final failure = mapper.map(error!, trace);
      expect(failure, const StorageFailure(StorageFailureKind.constraintViolated));
      expect(failure.isRetryable, isFalse);
    });

    test('the kept cause carries no SQL arguments', () async {
      await db.insert('t', {'id': 'a', 'name': 'Samsung fridge'});
      Object? error;
      try {
        await db.insert('t', {'id': 'a', 'name': 'Samsung fridge'});
      } catch (e) {
        error = e;
      }
      final failure = mapper.map(error!, trace);
      expect(failure.cause.toString(), isNot(contains('Samsung')));
    });

    test('a closed database means the scope closed (silent)', () async {
      await db.close();
      Object? error;
      try {
        await db.query('t');
      } catch (e) {
        error = e;
      }
      expect(mapper.map(error!, trace), const ScopeClosedFailure());
    });
  });
}
