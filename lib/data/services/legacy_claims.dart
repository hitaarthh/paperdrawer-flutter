import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import 'file_store.dart';

/// Table names of the removed claims feature (schema v6).
///
/// No screen reads these tables. Their rows stay in the drawer, travel with
/// "Export everything" and the legacy drawer import, and are removed only by
/// "Clear this drawer" after the user confirms. Schema v7 renames the tables
/// to `*_v6_backup`; that change is made here and nowhere else.
abstract final class LegacyClaimTables {
  static const claims = 'claims';
  static const events = 'claim_events';
  static const eventPhotos = 'claim_event_photos';

  /// Parents before children: the order rows are inserted in.
  static const all = [claims, events, eventPhotos];
}

/// The raw rows of the claim tables, exactly as stored.
@immutable
final class LegacyClaimRows {
  const LegacyClaimRows({
    required this.claims,
    required this.events,
    required this.eventPhotos,
  });

  static const empty = LegacyClaimRows(
    claims: [],
    events: [],
    eventPhotos: [],
  );

  final List<Map<String, Object?>> claims;
  final List<Map<String, Object?>> events;

  /// Each row's `rel_path` names a file under the drawer's `claim-photos/`.
  final List<Map<String, Object?>> eventPhotos;
}

/// Read and erase access to the claim rows a drawer may still hold.
abstract interface class LegacyClaims {
  /// Every claim row, read in one transaction.
  ///
  /// Throws if the drawer is closed or the database can't be read.
  Future<LegacyClaimRows> read();

  /// Deletes every claim row in one transaction, then removes the claim
  /// photos it referenced. Call only from "Clear this drawer" after the user
  /// has confirmed it.
  ///
  /// Throws if the drawer is closed or the delete fails; then no row is
  /// removed and every photo is kept.
  Future<void> eraseAll();
}

final class SqliteLegacyClaims implements LegacyClaims {
  SqliteLegacyClaims(this._db, this._files);

  final Database _db;
  final FileStore _files;
  Future<void> _pending = Future.value();
  bool _closed = false;

  @override
  Future<LegacyClaimRows> read() => _enqueue(
    () => _db.transaction(
      (txn) async => LegacyClaimRows(
        claims: _frozen(await txn.query(LegacyClaimTables.claims)),
        events: _frozen(await txn.query(LegacyClaimTables.events)),
        eventPhotos: _frozen(await txn.query(LegacyClaimTables.eventPhotos)),
      ),
    ),
  );

  @override
  Future<void> eraseAll() => _enqueue(() async {
    final photos = await _db.transaction((txn) async {
      final rows = await txn.query(
        LegacyClaimTables.eventPhotos,
        columns: ['rel_path'],
      );
      for (final table in LegacyClaimTables.all.reversed) {
        await txn.delete(table);
      }
      return [for (final row in rows) row['rel_path']! as String];
    });
    for (final relative in photos) {
      await _files.remove(_files.absolute(relative));
    }
  });

  /// Lets queued work finish and refuses new work; the drawer is closing.
  Future<void> finishWrites() {
    _closed = true;
    return _pending;
  }

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    if (_closed) return Future.error(StateError('This drawer is closed.'));
    final result = _pending.then((_) => operation());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  static List<Map<String, Object?>> _frozen(List<Map<String, Object?>> rows) =>
      List<Map<String, Object?>>.unmodifiable([
        for (final row in rows) Map<String, Object?>.unmodifiable(row),
      ]);
}
