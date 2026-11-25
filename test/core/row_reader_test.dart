import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrawer/core/data/row_mapper.dart';
import 'package:paperdrawer/core/data/sync_metadata.dart';
import 'package:paperdrawer/core/failure/app_failure.dart';
import 'package:paperdrawer/core/failure/failure_mapper.dart';
import 'package:paperdrawer/core/id/id_generator.dart';
import 'package:paperdrawer/core/time/clock.dart';

enum _Kind { bill, policy }

Matcher get _corrupt => throwsA(
  isA<FailureException>().having(
    (e) => e.failure,
    'failure',
    const StorageFailure(StorageFailureKind.corrupt),
  ),
);

void main() {
  RowReader row(Map<String, Object?> values) => RowReader('items', values);

  group('RowReader', () {
    test('reads typed columns', () {
      final r = row({'name': 'Fridge', 'amount': 4999, 'remind': 1});
      expect(r.string('name'), 'Fridge');
      expect(r.integer('amount'), 4999);
      expect(r.boolean('remind'), isTrue);
      expect(r.optionalString('missing'), isNull);
    });

    test('integral doubles are accepted, fractions are corrupt', () {
      expect(row({'n': 3.0}).integer('n'), 3);
      expect(() => row({'n': 3.5}).integer('n'), _corrupt);
    });

    test('missing or wrong-typed required columns are corrupt, not crashes', () {
      expect(() => row({}).string('name'), _corrupt);
      expect(() => row({'name': 3}).string('name'), _corrupt);
      expect(() => row({'amount': '12'}).optionalInt('amount'), _corrupt);
    });

    test('civil dates parse yyyy-mm-dd and reject impossible dates', () {
      expect(
        row({'d': '2026-11-25'}).optionalCivilDate('d'),
        DateTime.utc(2026, 11, 25),
      );
      expect(row({'d': ''}).optionalCivilDate('d'), isNull);
      expect(() => row({'d': '25/11/2026'}).optionalCivilDate('d'), _corrupt);
      expect(() => row({'d': '2026-02-30'}).optionalCivilDate('d'), _corrupt);
    });

    test('enums: known names, fallback for newer or missing values', () {
      expect(row({'k': 'policy'}).enumByName('k', _Kind.values), _Kind.policy);
      expect(
        row({'k': 'future'}).enumByName('k', _Kind.values, fallback: _Kind.bill),
        _Kind.bill,
      );
      expect(
        row({}).enumByName('k', _Kind.values, fallback: _Kind.bill),
        _Kind.bill,
      );
      expect(() => row({'k': 'future'}).enumByName('k', _Kind.values), _corrupt);
    });

    test('sync metadata round-trips through the row format', () {
      final meta = SyncMetadata(
        id: 'abc',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(2000),
        deletedAt: DateTime.fromMillisecondsSinceEpoch(3000),
        dirty: false,
        fieldUpdatedAt: {'name': DateTime.fromMillisecondsSinceEpoch(1500)},
      );
      expect(row(RowMapper.syncColumns(meta)).syncMetadata(), meta);
    });

    test('bad field_updated_at json is corrupt', () {
      final columns = RowMapper.syncColumns(
        SyncMetadata.created('x', DateTime(2026)),
      )..['field_updated_at'] = '{not json';
      expect(() => row(columns).syncMetadata(), _corrupt);
    });
  });

  group('SyncMetadata', () {
    final t0 = DateTime.utc(2026, 11, 25, 10);

    test('a new record is dirty', () {
      expect(SyncMetadata.created('a', t0).dirty, isTrue);
    });

    test('touched stamps the fields and marks dirty', () {
      final later = t0.add(const Duration(minutes: 1));
      final meta = SyncMetadata.created('a', t0).synced(t0).touched(
        later,
        fields: ['name'],
      );
      expect(meta.dirty, isTrue);
      expect(meta.updatedAt, later);
      expect(meta.fieldUpdatedAt['name'], later);
    });

    test('a clock moved backwards still produces a newer stamp', () {
      final earlier = t0.subtract(const Duration(hours: 1));
      final meta = SyncMetadata.created('a', t0).touched(earlier);
      expect(meta.updatedAt.isAfter(t0), isTrue);
    });

    test('deleted keeps the row as a marker', () {
      final meta = SyncMetadata.created('a', t0).deleted(t0.add(const Duration(seconds: 1)));
      expect(meta.isDeleted, isTrue);
      expect(meta.dirty, isTrue);
    });

    test('an upload confirmation for an older version keeps the row dirty', () {
      final v1 = SyncMetadata.created('a', t0);
      final v2 = v1.touched(t0.add(const Duration(seconds: 5)));
      expect(v2.synced(v1.updatedAt).dirty, isTrue, reason: 'v2 not uploaded');
      expect(v2.synced(v2.updatedAt).dirty, isFalse);
    });
  });

  group('Clock and IDs', () {
    test('FixedClock moves only when told, today is UTC midnight', () {
      final clock = FixedClock(DateTime(2026, 11, 25, 23, 59));
      expect(clock.today(), DateTime.utc(2026, 11, 25));
      clock.advance(const Duration(minutes: 2));
      expect(clock.today(), DateTime.utc(2026, 11, 26));
    });

    test('isUuid and the generators', () {
      expect(isUuid(const UuidGenerator().next()), isTrue);
      expect(isUuid('not-a-uuid'), isFalse);
      final ids = SequentialIdGenerator();
      expect([ids.next(), ids.next()], ['id-1', 'id-2']);
    });
  });
}
