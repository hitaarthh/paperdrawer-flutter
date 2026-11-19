import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/formats.dart';
import '../../domain/models/claim.dart';
import '../../domain/models/item.dart';
import 'file_store.dart';
import 'today.dart';

class Exporter {
  Exporter(this._files, {Today? today}) : _today = today ?? Today();

  final FileStore _files;
  final Today _today;

  Future<File> exportEverything({
    required List<Item> items,
    required List<Claim> claims,
  }) async {
    final cache = await getTemporaryDirectory();
    final folder = await cache.createTemp('paperdrawer-');
    final output = File(
      p.join(folder.path, 'paperdrawer-export-${isoDate(_today.value)}.zip'),
    );
    final zip = ZipFileEncoder();
    try {
      zip.create(output.path);
      try {
        final json = const JsonEncoder.withIndent('  ').convert({
          'version': 3,
          'items': items.map(_encodeItem).toList(),
          'claims': claims.map(_encodeClaim).toList(),
        });
        zip.addArchiveFile(ArchiveFile.string('paperdrawer.json', json));
        for (final item in items) {
          for (final attachment in item.attachments) {
            final path = _files.absolute(_files.relative(attachment.path));
            await zip.addFile(File(path), _archivePath(item, attachment));
          }
        }
        for (final claim in claims) {
          for (final event in claim.events) {
            if (event.photo case final photo?) {
              final path = _files.absolute(_files.relative(photo.path));
              await zip.addFile(File(path), _claimPhotoPath(claim, photo));
            }
          }
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

  Future<List<XFile>> claimKit(Item item, {Claim? claim}) async => [
    for (final attachment in item.attachments)
      XFile(attachment.path, name: attachment.name),
    claimKitSummary(item, claim: claim),
  ];

  static XFile claimKitSummary(Item item, {Claim? claim}) {
    final draft = item.draft;
    final amount = draft.amountMinor;
    final summary = [
      item.name,
      item.kind.label,
      if (draft.source.isNotEmpty) draft.source,
      if (draft.reference.isNotEmpty) 'Reference: ${draft.reference}',
      if (draft.serialNumber.isNotEmpty) 'Serial number: ${draft.serialNumber}',
      if (draft.startsOn case final date?) 'Date: ${longDate(date)}',
      if (amount != null) 'Amount: ${money(amount, draft.currency)}',
      if (draft.returnUntil case final date?) 'Return by: ${longDate(date)}',
      if (draft.coverUntil case final date?) 'Cover ends: ${longDate(date)}',
      if (draft.componentWarrantyUntil case final date?)
        '${draft.componentWarrantyName.isEmpty ? 'Component' : draft.componentWarrantyName} '
            'warranty ends: ${longDate(date)}',
      if (draft.notes.isNotEmpty) draft.notes,
      if (claim != null) ...[
        '',
        claim.title,
        claim.problem,
        'Requested: ${claim.want.phrase}',
      ],
    ].join('\n');
    final name = '${_safeName(item.name)}-claim-kit.txt';
    return XFile.fromData(
      Uint8List.fromList(utf8.encode(summary)),
      name: name,
      mimeType: 'text/plain',
    );
  }

  String _archivePath(Item item, Attachment file) =>
      'originals/${item.id}/${file.id}-${_safeName(file.name)}';

  String _claimPhotoPath(Claim claim, Attachment file) =>
      'claim-photos/${claim.id}/${file.id}-${_safeName(file.name)}';

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

  Map<String, Object?> _encodeClaim(Claim claim) => {
    'id': claim.id,
    'item_id': claim.itemId,
    'item_label': claim.itemLabel,
    'type': claim.type.name,
    'want': claim.want.name,
    'problem': claim.problem,
    'reference': claim.reference,
    'opened_on': isoDate(claim.openedOn),
    'noticed_on': _date(claim.noticedOn),
    'step': claim.step,
    'step_since': isoDate(claim.stepSince),
    'last_heard_on': _date(claim.lastHeardOn),
    'settled_on': _date(claim.settledOn),
    'nudge_days': claim.nudgeDays,
    'follow_up_at': claim.followUp?.toUtc().toIso8601String(),
    'events': [
      for (final event in claim.events)
        {
          'id': event.id,
          'on': isoDate(event.on),
          'kind': event.kind.name,
          'text': event.text,
          'reference': event.reference,
          if (event.photo case final photo?)
            'photo': {
              'name': photo.name,
              'path': _claimPhotoPath(claim, photo),
              'bytes': photo.bytes,
            },
        },
    ],
  };

  String? _date(DateTime? value) => value == null ? null : isoDate(value);
}
