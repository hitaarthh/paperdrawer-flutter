import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/formats.dart';
import '../../domain/models/item.dart';
import 'file_store.dart';
import 'legacy_claims.dart';
import 'today.dart';

class Exporter {
  Exporter(
    this._files, {
    Today? today,
    Future<Directory> Function() temporaryDirectory = getTemporaryDirectory,
  }) : _today = today ?? Today(),
       _temporaryDirectory = temporaryDirectory;

  final FileStore _files;
  final Today _today;
  final Future<Directory> Function() _temporaryDirectory;

  /// Writes every item, its originals, and the rows and photos the removed
  /// claims feature left in this drawer into one zip.
  ///
  /// Throws if a file can't be read or the zip can't be written; then no
  /// export file is left behind.
  Future<File> exportEverything({
    required List<Item> items,
    required LegacyClaimRows claims,
  }) async {
    final cache = await _temporaryDirectory();
    final folder = await cache.createTemp('paperdrawer-');
    final output = File(
      p.join(folder.path, 'paperdrawer-export-${isoDate(_today.value)}.zip'),
    );
    final zip = ZipFileEncoder();
    try {
      zip.create(output.path);
      try {
        final json = const JsonEncoder.withIndent('  ').convert({
          'version': 4,
          'items': items.map(_encodeItem).toList(),
          'legacy_claims': _encodeClaims(claims),
        });
        zip.addArchiveFile(ArchiveFile.string('paperdrawer.json', json));
        for (final item in items) {
          for (final attachment in item.attachments) {
            final path = _files.absolute(_files.relative(attachment.path));
            await zip.addFile(File(path), _archivePath(item, attachment));
          }
        }
        for (final photo in claims.eventPhotos) {
          final path = _files.absolute(photo['rel_path']! as String);
          await zip.addFile(File(path), _claimPhotoPath(photo));
        }
      } finally {
        await zip.close();
      }
      return output;
    } catch (_) {
      await folder.delete(recursive: true);
      rethrow;
    }
  }

  Future<void> discardExport(File export) =>
      export.parent.delete(recursive: true);

  String _archivePath(Item item, Attachment file) =>
      'originals/${item.id}/${file.id}-${_safeName(file.name)}';

  /// One folder per claim event; an event has at most one photo.
  String _claimPhotoPath(Map<String, Object?> photo) {
    final name = _safeName(photo['name']! as String);
    return 'claim-photos/${photo['event_id']}/$name';
  }

  static String _safeName(String name) =>
      name.replaceAll(RegExp(r'[\\/:\x00-\x1f]'), '-');

  Map<String, Object?> _encodeItem(Item item) => {
    'id': item.id,
    'kind': item.kind.name,
    'name': item.name,
    'source': item.draft.source,
    'subtype': item.draft.subtype,
    'reference': item.draft.reference,
    'serial_number': item.draft.serialNumber,
    'notes': item.draft.notes,
    'amount_minor': item.draft.amountMinor,
    'currency': item.draft.currency,
    'starts_on': _date(item.draft.startsOn),
    'return_until': _date(item.draft.returnUntil),
    'cover_until': _date(item.draft.coverUntil),
    'component_warranty_until': _date(item.draft.componentWarrantyUntil),
    'component_warranty_name': item.draft.componentWarrantyName,
    'remind': item.draft.remind,
    'reminder_at': item.draft.reminderAt?.toUtc().toIso8601String(),
    'coverage_renews': item.draft.coverageRenews,
    'created_at': item.createdAt.toUtc().toIso8601String(),
    'archived_at': item.archivedAt?.toUtc().toIso8601String(),
    'attachments': [
      for (final file in item.attachments)
        {
          'id': file.id,
          'name': file.name,
          'bytes': file.bytes,
          'path': _archivePath(item, file),
        },
    ],
  };

  /// Raw rows under fixed keys, so the export format doesn't change when the
  /// tables are renamed. Each photo row gains the `path` of its copy in the
  /// zip.
  Map<String, Object?> _encodeClaims(LegacyClaimRows claims) => {
    'claims': claims.claims,
    'claim_events': claims.events,
    'claim_event_photos': [
      for (final photo in claims.eventPhotos)
        {...photo, 'path': _claimPhotoPath(photo)},
    ],
  };

  String? _date(DateTime? value) => value == null ? null : isoDate(value);
}
