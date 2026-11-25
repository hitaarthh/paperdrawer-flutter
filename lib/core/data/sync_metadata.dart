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
  ///
  /// The new time never goes backwards: if the phone's clock was moved back,
  /// the edit is still stamped 1 ms after the previous one, so a newer edit
  /// can't lose a merge to an older one.
  SyncMetadata touched(DateTime now, {Iterable<String> fields = const []}) {
    final stamp = _after(now);
    return SyncMetadata(
      id: id,
      createdAt: createdAt,
      updatedAt: stamp,
      deletedAt: deletedAt,
      dirty: true,
      fieldUpdatedAt: {
        ...fieldUpdatedAt,
        for (final field in fields) field: stamp,
      },
    );
  }

  /// Metadata after a local delete. The row stays as a marker.
  SyncMetadata deleted(DateTime now) {
    final stamp = _after(now);
    return SyncMetadata(
      id: id,
      createdAt: createdAt,
      updatedAt: stamp,
      deletedAt: stamp,
      dirty: true,
      fieldUpdatedAt: fieldUpdatedAt,
    );
  }

  /// Metadata after an upload of the version stamped [uploadedUpdatedAt] was
  /// confirmed. If the record changed again while uploading, it stays dirty
  /// so the newer edit is uploaded too. In SQL this is
  /// `UPDATE … SET dirty = 0 WHERE id = ? AND updated_at = ?`.
  SyncMetadata synced(DateTime uploadedUpdatedAt) {
    if (uploadedUpdatedAt != updatedAt) return this;
    return SyncMetadata(
      id: id,
      createdAt: createdAt,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
      dirty: false,
      fieldUpdatedAt: fieldUpdatedAt,
    );
  }

  DateTime _after(DateTime now) => now.isAfter(updatedAt)
      ? now
      : updatedAt.add(const Duration(milliseconds: 1));

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
