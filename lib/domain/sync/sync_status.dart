import 'package:flutter/foundation.dart';

import '../../core/failure/app_failure.dart';

/// What the sync row in Settings shows: Synced · Syncing 3 items ·
/// Paused (reason) · Last synced 2 min ago.
@immutable
sealed class SyncStatus {
  const SyncStatus();
}

/// No sync on this plan (Base), or not started yet.
final class SyncOff extends SyncStatus {
  const SyncOff();

  @override
  bool operator ==(Object other) => other is SyncOff;

  @override
  int get hashCode => (SyncOff).hashCode;
}

/// Everything uploaded. [lastSyncedAt] is null before the first sync ends.
final class SyncIdle extends SyncStatus {
  const SyncIdle({this.lastSyncedAt});

  final DateTime? lastSyncedAt;

  @override
  bool operator ==(Object other) =>
      other is SyncIdle && other.lastSyncedAt == lastSyncedAt;

  @override
  int get hashCode => lastSyncedAt.hashCode;
}

/// Uploading or downloading. [pending] counts records left to upload.
final class SyncRunning extends SyncStatus {
  const SyncRunning({required this.pending, this.isFullUpload = false});

  final int pending;

  /// True for the first upload after an upgrade ("Backing up 42 items…").
  final bool isFullUpload;

  @override
  bool operator ==(Object other) =>
      other is SyncRunning &&
      other.pending == pending &&
      other.isFullUpload == isFullUpload;

  @override
  int get hashCode => Object.hash(pending, isFullUpload);
}

/// Stopped until [reason] clears. The app keeps working locally.
final class SyncPaused extends SyncStatus {
  const SyncPaused(this.reason, {required this.since});

  final SyncPauseReason reason;
  final DateTime since;

  @override
  bool operator ==(Object other) =>
      other is SyncPaused && other.reason == reason && other.since == since;

  @override
  int get hashCode => Object.hash(reason, since);
}
