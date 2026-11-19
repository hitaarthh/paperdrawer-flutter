import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../domain/models/item.dart';

const maxAttachmentBytes = 20 * 1024 * 1024;

const attachmentExtensions = {
  '.pdf',
  '.jpg',
  '.jpeg',
  '.png',
  '.heic',
  '.heif',
  '.webp',
};

/// Keeps the originals (bill photos, policy PDFs) in the app's private
/// storage. The database stores paths relative to [root], so the drawer
/// survives the app container moving between installs and restores.
class FileStore {
  FileStore(this.root);

  final Directory root;

  Directory get _attachments => Directory(p.join(root.path, 'attachments'));

  String absolute(String relPath) => p.join(root.path, relPath);

  String relative(String absPath) => p.relative(absPath, from: root.path);

  /// Copies [file] into the drawer for [itemId]. The picked file is left
  /// where it was; picker and camera files are temporary.
  Future<Attachment> import(String itemId, PendingFile file, {bool claimPhoto = false}) async {
    final source = File(file.path);
    final ext = p
        .extension(file.name.isEmpty ? file.path : file.name)
        .toLowerCase();
    final message = claimPhoto ? 'Choose a photo up to 20 MB.' : 'Choose a photo or PDF up to 20 MB.';
    if (!attachmentExtensions.contains(ext) || (claimPhoto && ext == '.pdf') || !await source.exists()) {
      throw FormatException(message);
    }
    final bytes = await source.length();
    if (bytes == 0 || bytes > maxAttachmentBytes) {
      throw FormatException(message);
    }

    final id = const Uuid().v4();
    final folder = claimPhoto ? p.join(root.path, 'claim-photos') : _attachments.path;
    final target = File(p.join(folder, '$itemId-$id$ext'));
    await target.parent.create(recursive: true);
    try {
      await source.copy(target.path);
    } catch (_) {
      await remove(target.path);
      rethrow;
    }
    return Attachment(
      id: id,
      path: target.path,
      name: file.name.isEmpty ? p.basename(file.path) : file.name,
      bytes: bytes,
    );
  }

  Future<void> remove(String absPath) async {
    try {
      final file = File(absPath);
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // Already gone, or the OS refused; nothing the user can act on.
    }
  }

  Future<void> removeAll() async {
    if (await _attachments.exists()) {
      await _attachments.delete(recursive: true);
    }
  }
}
