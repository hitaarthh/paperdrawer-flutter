import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrawer/core/data/row_mapper.dart';
import 'package:paperdrawer/core/data/sync_metadata.dart';
import 'package:paperdrawer/core/failure/app_failure.dart';
import 'package:paperdrawer/core/failure/failure_mapper.dart';

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

  test('reads typed columns', () {
    final r = row({'name': 'Fridge', 'amount': 4999, 'remind': 1});
    expect(r.string('name'), 'Fridge');
    expect(r.integer('amount'), 4999);
    expect(r.boolean('remind'), isTrue);
    expect(r.optionalString('missing'), isNull);
  });

  test('missing or wrong-typed required columns are corrupt, not crashes', () {
    expect(() => row({}).string('name'), _corrupt);
    expect(() => row({'name': 3}).string('name'), _corrupt);
    expect(() => row({'amount': '12'}).optionalInt('amount'), _corrupt);
  });

  test('civil dates parse yyyy-mm-dd and reject impossible dates', () {
    expect(
      row({'d': '2026-11-25'}).optionalCivilDate('d'),
      DateTime(2026, 11, 25),
    );
    expect(row({'d': ''}).optionalCivilDate('d'), isNull);
    expect(() => row({'d': '25/11/2026'}).optionalCivilDate('d'), _corrupt);
    expect(() => row({'d': '2026-02-30'}).optionalCivilDate('d'), _corrupt);
  });

  test('enums: known names, fallback for newer values, else corrupt', () {
    expect(row({'k': 'policy'}).enumByName('k', _Kind.values), _Kind.policy);
    expect(
      row({'k': 'future'}).enumByName('k', _Kind.values, fallback: _Kind.bill),
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
    final decoded = row(RowMapper.syncColumns(meta)).syncMetadata();
    expect(decoded, meta);
  });

  test('bad field_updated_at json is corrupt', () {
    final columns = RowMapper.syncColumns(
      SyncMetadata.created('x', DateTime(2026)),
    )..['field_updated_at'] = '{not json';
    expect(() => row(columns).syncMetadata(), _corrupt);
  });
}
