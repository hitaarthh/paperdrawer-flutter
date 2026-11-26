import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../repositories/item_repository.dart';
import '../repositories/settings_repository.dart';
import 'app_database.dart';
import 'file_store.dart';
import 'legacy_claims.dart';
import 'legacy_drawer_import.dart';

/// The auth ID is stable across email changes. The project isolates test and
/// production accounts, even when their user IDs happen to match.
class DrawerOwner {
  DrawerOwner(Uri project, String userId)
    : key = '${base64Url.encode(utf8.encode(project.origin))}/${_uuid(userId)}';

  final String key;

  static String _uuid(String value) {
    if (!RegExp(r'^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$')
        .hasMatch(value)) {
      throw const FormatException('This account couldn’t open a drawer.');
    }
    return value;
  }
}

class DrawerStorage {
  const DrawerStorage(this.root, {this._factory});

  final Directory root;
  final DatabaseFactory? _factory;

  Future<LocalDrawer> open({DrawerOwner? owner}) async {
    final directory = _directory(owner);
    await directory.create(recursive: true);
    final db = await AppDatabase.open(_path(directory), factory: _factory);
    final files = FileStore(directory);
    final settings = SettingsRepository(
      db,
      syncsAccountSettings: owner != null,
    );
    final items = ItemRepository(
      db,
      files,
      onBasePlan: () => settings.onBasePlan,
    );
    // Claim rows are kept as they are; nothing parses them on open.
    final legacyClaims = SqliteLegacyClaims(db, files);
    final drawer = LocalDrawer(
      db,
      files,
      settings,
      items,
      legacyClaims,
      owner?.key,
    );
    try {
      if (owner == null && await LegacyDrawerImport.isClaimed(db)) {
        throw const FormatException('Sign in to open your drawer.');
      }
      if (owner != null) await _recoverOriginals(db, files);
      await Future.wait([settings.load(), items.load()]);
      return drawer;
    } catch (_) {
      await drawer.close();
      rethrow;
    }
  }

  Future<bool> canImportLegacy(DrawerOwner owner, LocalDrawer drawer) async {
    if (drawer._ownerKey != owner.key) return false;
    final path = _path(root);
    if (!await File(path).exists()) return false;
    final source = await AppDatabase.open(path, factory: _factory);
    try {
      final legacy = LegacyDrawerImport(source, root);
      return !await legacy.isImported(drawer._db) &&
          await legacy.canImport(owner.key);
    } finally {
      await source.close();
    }
  }

  Future<void> importLegacy(DrawerOwner owner, LocalDrawer drawer) async {
    if (drawer._ownerKey != owner.key) {
      throw StateError('The drawer belongs to another account.');
    }
    final path = _path(root);
    if (!await File(path).exists()) return;
    final source = await AppDatabase.open(path, factory: _factory);
    try {
      await LegacyDrawerImport(
        source,
        root,
      ).copyTo(owner.key, drawer._db, drawer.files);
      await Future.wait([drawer.items.load(), drawer.settings.load()]);
    } finally {
      await source.close();
    }
  }

  Directory _directory(DrawerOwner? owner) => owner == null
      ? root
      : Directory(p.join(root.path, 'accounts', owner.key));

  String _path(Directory directory) => p.join(directory.path, 'vault.sqlite');

  /// Keeps every original a row refers to, claim photos included.
  Future<void> _recoverOriginals(Database db, FileStore files) async {
    final rows = await db.rawQuery('''
      SELECT rel_path FROM attachments
      UNION SELECT rel_path FROM ${LegacyClaimTables.eventPhotos}
    ''');
    await files.removeUnreferenced(
      rows.map((row) => row['rel_path']! as String).toSet(),
    );
  }
}

class LocalDrawer {
  const LocalDrawer(
    this._db,
    this.files,
    this.settings,
    this.items,
    this.legacyClaims,
    this._ownerKey,
  );

  final Database _db;
  final FileStore files;
  final SettingsRepository settings;
  final ItemRepository items;
  final SqliteLegacyClaims legacyClaims;
  final String? _ownerKey;

  Future<void> close() async {
    await Future.wait([
      settings.finishWrites(),
      items.finishWrites(),
      legacyClaims.finishWrites(),
    ]);
    settings.dispose();
    items.dispose();
    await _db.close();
  }
}
