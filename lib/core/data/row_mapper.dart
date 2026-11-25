import 'dart:convert';

import '../failure/app_failure.dart';
import '../failure/failure_mapper.dart';
import 'sync_metadata.dart';

/// Converts between one domain model and one database row (data mapper).
///
/// Every table has exactly one mapper. Mappers are the only code that knows
/// column names, so a schema change touches the migration and the mapper and
/// nothing else.
abstract base class RowMapper<T> {
  const RowMapper();

  /// The table this mapper reads and writes.
  String get table;

  T fromRow(RowReader row);

  Map<String, Object?> toRow(T value);

  /// Reads [row]. A malformed row becomes a [StorageFailure] with kind
  /// `corrupt`, carried through a [FailureException], instead of a cast error
  /// deep in the UI.
  T decode(Map<String, Object?> row) => fromRow(RowReader(table, row));

  /// The sync columns every synced table has (schema v7+).
  static Map<String, Object?> syncColumns(SyncMetadata meta) => {
    'id': meta.id,
    'created_at': meta.createdAt.millisecondsSinceEpoch,
    'updated_at': meta.updatedAt.millisecondsSinceEpoch,
    'deleted_at': meta.deletedAt?.millisecondsSinceEpoch,
    'dirty': meta.dirty ? 1 : 0,
    'field_updated_at': jsonEncode({
      for (final entry in meta.fieldUpdatedAt.entries)
        entry.key: entry.value.millisecondsSinceEpoch,
    }),
  };
}

/// Typed, checked access to one database row.
///
/// Every getter throws a [FailureException] holding
/// `StorageFailure(StorageFailureKind.corrupt)` when a column is missing or has
/// the wrong type, so one bad row is reported clearly instead of crashing.
final class RowReader {
  RowReader(this.table, this._row);

  final String table;
  final Map<String, Object?> _row;

  String string(String column) => _required<String>(column);

  String stringOr(String column, [String fallback = '']) =>
      _optional<String>(column) ?? fallback;

  String? optionalString(String column) {
    final value = _optional<String>(column);
    return value == null || value.isEmpty ? null : value;
  }

  /// Accepts any integral number (SQLite can hand back `1.0` for REAL
  /// affinity or JSON-sourced values).
  int integer(String column) => _integral(column, _required<num>(column));

  int? optionalInt(String column) => switch (_optional<num>(column)) {
    null => null,
    final value => _integral(column, value),
  };

  bool boolean(String column, {bool fallback = false}) =>
      switch (optionalInt(column)) {
        null => fallback,
        final value => value != 0,
      };

  /// An instant stored as epoch milliseconds.
  DateTime instant(String column) =>
      DateTime.fromMillisecondsSinceEpoch(integer(column));

  DateTime? optionalInstant(String column) => switch (optionalInt(column)) {
    null => null,
    final ms => DateTime.fromMillisecondsSinceEpoch(ms),
  };

  /// A civil date stored as `yyyy-mm-dd`, returned as UTC midnight (the
  /// app-wide civil date convention, see `civilDate`).
  DateTime? optionalCivilDate(String column) {
    final text = optionalString(column);
    if (text == null) return null;
    final match = _isoDate.firstMatch(text);
    if (match == null) throw _corrupt(column, 'not yyyy-mm-dd');
    final date = DateTime.utc(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
    // Reject rolled-over dates such as 2026-02-30.
    if (date.month != int.parse(match.group(2)!)) {
      throw _corrupt(column, 'impossible date');
    }
    return date;
  }

  /// An enum stored by its `name`. Unknown names fall back to [fallback] when
  /// given (forward compatibility with newer app versions), else are corrupt.
  E enumByName<E extends Enum>(String column, List<E> values, {E? fallback}) {
    final name = optionalString(column);
    if (name == null) {
      if (fallback != null) return fallback;
      throw _corrupt(column, 'missing');
    }
    for (final value in values) {
      if (value.name == name) return value;
    }
    if (fallback != null) return fallback;
    throw _corrupt(column, 'unknown value');
  }

  /// The sync columns (schema v7+).
  SyncMetadata syncMetadata() {
    final raw = stringOr('field_updated_at', '{}');
    Map<String, DateTime> fields;
    try {
      final decoded = jsonDecode(raw.isEmpty ? '{}' : raw);
      fields = {
        for (final entry in (decoded as Map<String, dynamic>).entries)
          entry.key: DateTime.fromMillisecondsSinceEpoch(entry.value as int),
      };
    } catch (_) {
      throw _corrupt('field_updated_at', 'bad json');
    }
    return SyncMetadata(
      id: string('id'),
      createdAt: instant('created_at'),
      updatedAt: instant('updated_at'),
      deletedAt: optionalInstant('deleted_at'),
      dirty: boolean('dirty', fallback: true),
      fieldUpdatedAt: fields,
    );
  }

  int _integral(String column, num value) {
    if (value is int) return value;
    if (value == value.truncateToDouble()) return value.toInt();
    throw _corrupt(column, 'not a whole number');
  }

  V _required<V>(String column) {
    final value = _row[column];
    if (value is V) return value;
    throw _corrupt(column, value == null ? 'missing' : 'wrong type');
  }

  V? _optional<V>(String column) {
    final value = _row[column];
    if (value == null) return null;
    if (value is V) return value;
    throw _corrupt(column, 'wrong type');
  }

  FailureException _corrupt(String column, String why) => FailureException(
    StorageFailure(
      StorageFailureKind.corrupt,
      cause: StateError('$table.$column: $why'),
    ),
  );

  static final _isoDate = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
}
