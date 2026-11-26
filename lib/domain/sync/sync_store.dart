import 'package:flutter/foundation.dart';

import '../../core/data/sync_metadata.dart';
import '../../core/result/result.dart';
import '../plans/plan.dart';

/// The kinds of record that travel between devices.
///
/// Settings sync separately (keyed rows, `AccountSettingsSync`); claim backups
/// never sync.
enum SyncEntity { item, attachment }

/// One record as a transport sees it: its sync bookkeeping plus its fields
/// as plain JSON-safe values (strings, numbers, booleans, null).
///
/// Field names are the wire names shared by every transport and the server
/// (snake_case, as in the database). A transport never interprets fields; it
/// only carries them.
@immutable
final class SyncRecord {
  const SyncRecord({
    required this.entity,
    required this.meta,
    required this.fields,
  });

  final SyncEntity entity;
  final SyncMetadata meta;
  final Map<String, Object?> fields;

  String get id => meta.id;
}

/// "Version X of this record was uploaded." Used to clear `dirty` only if
/// the record hasn't changed again since (see `SyncMetadata.synced`).
@immutable
final class SyncVersion {
  const SyncVersion({
    required this.entity,
    required this.id,
    required this.updatedAt,
  });

  final SyncEntity entity;
  final String id;
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) =>
      other is SyncVersion &&
      other.entity == entity &&
      other.id == id &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(entity, id, updatedAt);
}

/// An original (photo or PDF) whose bytes must travel.
@immutable
final class SyncFile {
  const SyncFile({
    required this.attachmentId,
    required this.relativePath,
    required this.bytes,
    this.contentHash,
  });

  final String attachmentId;

  /// Relative to the drawer folder (`attachments/...`).
  final String relativePath;
  final int bytes;

  /// SHA-256 hex of the content, when known. Identical files upload once.
  final String? contentHash;
}

/// The result of applying remote records.
@immutable
final class ApplyOutcome {
  const ApplyOutcome({required this.changed, required this.conflictsMerged});

  /// Records whose local copy changed.
  final int changed;

  /// Records where both sides had edits and fields were merged.
  final int conflictsMerged;
}

/// What a sync transport needs from the open drawer's database (port).
///
/// Implemented by the data layer over the drawer's SQLite file, bound to one
/// account. Every method returns a [Result] and never throws. All writes go
/// through the drawer's shared write queue, so sync never interleaves with a
/// user's save.
///
/// Merge rule (implemented behind [applyRemote], shared by every transport):
/// field by field, the newer `field_updated_at` wins; a delete marker wins
/// over edits older than it; equal stamps keep the local value. Applying the
/// same remote record twice changes nothing (idempotent).
abstract interface class SyncStore {
  /// Records changed on this phone and not yet uploaded, oldest first.
  Future<Result<List<SyncRecord>>> pendingChanges({int limit = 200});

  /// Every record, in ID order, for a full upload. Pass the last ID of the
  /// previous page as [afterId].
  Future<Result<List<SyncRecord>>> allRecords({String? afterId, int limit = 200});

  /// Clears `dirty` for records whose current version is still the uploaded
  /// one. Records edited during the upload stay dirty.
  Future<Result<Unit>> markUploaded(List<SyncVersion> versions);

  /// Merges records from the cloud into the drawer and notifies the
  /// repositories so screens refresh.
  Future<Result<ApplyOutcome>> applyRemote(List<SyncRecord> records);

  /// Originals that exist locally and still need uploading for [kind].
  Future<Result<List<SyncFile>>> filesToUpload(SyncKind kind, {int limit = 20});

  /// Originals referenced by synced attachments but missing on this phone.
  Future<Result<List<SyncFile>>> filesToDownload({int limit = 20});

  /// Records that [file] is now stored remotely for [kind].
  Future<Result<Unit>> markFileUploaded(SyncKind kind, SyncFile file);

  /// Stores downloaded bytes for [file] (written atomically) and links them.
  Future<Result<Unit>> saveDownloadedFile(SyncFile file, List<int> bytes);

  /// The transport's saved position in the remote change stream, if any.
  Future<Result<String?>> readCursor(SyncKind kind);

  Future<Result<Unit>> writeCursor(SyncKind kind, String cursor);
}

/// Creates the [SyncStore] for the open drawer. The coordinator hands it to
/// the transport it starts.
abstract interface class SyncStoreProvider {
  SyncStore get current;
}
