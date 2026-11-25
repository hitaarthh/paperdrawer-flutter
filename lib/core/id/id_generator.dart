import 'package:uuid/uuid.dart';

/// Creates record IDs on the phone.
///
/// IDs are UUID v4 strings created on the device that first saved the record,
/// and they never change. Sync, import and export match rows by this ID, so
/// doing any of them twice never duplicates a row.
abstract interface class IdGenerator {
  String next();
}

final class UuidGenerator implements IdGenerator {
  const UuidGenerator();

  static const _uuid = Uuid();

  @override
  String next() => _uuid.v4();
}

/// Predictable IDs (`id-1`, `id-2`, …) for tests.
final class SequentialIdGenerator implements IdGenerator {
  SequentialIdGenerator({this.prefix = 'id'});

  final String prefix;
  int _count = 0;

  @override
  String next() => '$prefix-${++_count}';
}

/// True for a canonical lowercase or uppercase UUID string.
bool isUuid(String value) => _uuidPattern.hasMatch(value);

final _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
