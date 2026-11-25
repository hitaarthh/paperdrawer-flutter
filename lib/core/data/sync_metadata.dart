import 'package:flutter/foundation.dart';

/// The bookkeeping every synced record carries, on every plan.
///
/// Base never syncs, but its rows still carry these fields so upgrading to
/// Essential or Pro never needs a data rewrite (spec: "Ready for sync from day
/// one").
///
/// - [id] is created on the phone (UUID v4) and never changes.
/// - [deletedAt] makes a delete a marker, so other devices learn about it.
/// - [dirty] means changed here and not yet uploaded.
/// - [fieldUpdatedAt] holds when each field last changed, for field-by-field
///   merging (two devices editing different fields both keep their change).
@immutable
final class SyncMetadata {
  const SyncMetadata({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.dirty = true,
    this.fieldUpdatedAt = const {},
  });

  /// Metadata for a record created now.
  factory SyncMetadata.created(String id, DateTime now) =>
      SyncMetadata(id: id, createdAt: now, updatedAt: now);

  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final bool dirty;
  final Map<String, DateTime> fieldUpdatedAt;

  bool get isDeleted => deletedAt != null;

  /// Metadata after a local edit to [fields].
  SyncMetadata touched(DateTime now, {Iterable<String> fields = const []}) =>
      SyncMetadata(
        id: id,
        createdAt: createdAt,
        updatedAt: now,
        deletedAt: deletedAt,
        dirty: true,
        fieldUpdatedAt: {...fieldUpdatedAt, for (final field in fields) field: now},
      );

  /// Metadata after a local delete. The row stays as a marker.
  SyncMetadata deleted(DateTime now) => SyncMetadata(
    id: id,
    createdAt: createdAt,
    updatedAt: now,
    deletedAt: now,
    dirty: true,
    fieldUpdatedAt: fieldUpdatedAt,
  );

  /// Metadata after an upload was confirmed.
  SyncMetadata synced() => SyncMetadata(
    id: id,
    createdAt: createdAt,
    updatedAt: updatedAt,
    deletedAt: deletedAt,
    dirty: false,
    fieldUpdatedAt: fieldUpdatedAt,
  );

  @override
  bool operator ==(Object other) =>
      other is SyncMetadata &&
      other.id == id &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.deletedAt == deletedAt &&
      other.dirty == dirty &&
      mapEquals(other.fieldUpdatedAt, fieldUpdatedAt);

  @override
  int get hashCode => Object.hash(id, createdAt, updatedAt, deletedAt, dirty);
}

/// A record that can travel between devices.
///
/// Domain models that sync (items, attachments, settings) implement this, so
/// the sync engine can treat them uniformly without knowing their fields.
abstract interface class SyncedEntity {
  SyncMetadata get meta;
}
