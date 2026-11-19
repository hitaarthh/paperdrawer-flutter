import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../domain/formats.dart';
import '../../domain/models/item.dart';
import '../../domain/models/shared_vault.dart';
import 'file_store.dart' show maxAttachmentBytes;

/// Writes shared items and their originals to the owner's private drawer.
class SharedItemWrite {
  const SharedItemWrite(this._client);

  final SupabaseClient _client;

  Future<void> save(
    String owner,
    String id,
    ItemDraft draft, {
    PendingFile? original,
  }) async {
    final bill = draft.kind == ItemKind.bill;
    final params = arguments(id, draft);
    final attachment = original == null
        ? null
        : await _upload(owner, id, original);
    try {
      _requireOwner(owner);
      await _client.rpc<List<dynamic>>(
        bill ? 'save_bill' : 'save_document',
        params: {...params, 'p_file': ?attachment},
      );
    } on PostgrestException catch (error) {
      // Only remove the upload when the database explicitly rejected the
      // transaction. A lost response can happen after it committed.
      if (attachment != null &&
          error.code?.length == 5 &&
          _client.auth.currentUser?.id == owner) {
        try {
          await _client.storage.from('vault').remove([
            attachment['storage_path']! as String,
          ]);
        } catch (_) {
          // Keep the original save error if storage is unavailable.
        }
      }
      if (error.code == 'CL001') {
        throw const FormatException(
          'Your Base vault is full. Make room before adding another item.',
        );
      }
      rethrow;
    }
  }

  Future<void> edit(
    String owner,
    SharedItem item,
    ItemDraft draft, {
    required PendingFile? original,
    required String? uploadId,
  }) async {
    _requireOwner(owner);
    final revision = item.updatedAt;
    if (revision == null) {
      throw const FormatException('Refresh your drawer and reopen this item.');
    }
    if (draft.kind != item.item.kind) {
      throw const FormatException('Keep the existing item type.');
    }
    final changes = _editFields(draft);
    final bill = draft.kind == ItemKind.bill;
    final table = bill ? 'bills' : 'documents';
    final id = item.item.id;
    final file = original == null
        ? null
        : await _upload(owner, uploadId!, original);
    final uploadPath = file?['storage_path'] as String?;
    try {
      _requireOwner(owner);
      if (file == null) {
        final updated = await _client
            .from(table)
            .update(changes)
            .eq('user_id', owner)
            .eq('id', id)
            .eq('updated_at', revision)
            .select('id')
            .maybeSingle();
        if (updated != null) return;
      } else {
        final replaced = await _client.rpc<List<dynamic>>(
          'edit_item_with_original',
          params: {
            'p_id': id,
            'p_bill': bill,
            'p_expected_updated_at': revision,
            'p_name': changes['name'],
            'p_date': changes[bill ? 'purchased_on' : 'end_on'],
            'p_warranty_months': changes['warranty_months'],
            'p_file': file,
          },
        );
        await _removeFiles(owner, replaced.whereType<String>());
        return;
      }
    } on PostgrestException catch (error) {
      final missingRpc = error.code == 'PGRST202';
      if (uploadPath != null && (error.code?.length == 5 || missingRpc)) {
        await _discardUnlinkedUpload(owner, uploadPath);
      }
      if (missingRpc) {
        throw const FormatException(
          'File replacement is temporarily unavailable. You can save the other changes with the current file.',
        );
      }
      if (error.code != 'CL004') rethrow;
    }
    // A lost response can leave the form holding the old revision. Finish a
    // retry only if the requested values and replacement are already saved.
    final latest = await _client
        .from(table)
        .select([...changes.keys, 'attachments(storage_path)'].join(','))
        .eq('user_id', owner)
        .eq('id', id)
        .maybeSingle();
    if (latest == null) {
      throw const FormatException('This item is no longer in your drawer.');
    }
    final matches = changes.entries.every(
      (entry) => latest[entry.key] == entry.value,
    );
    final files = latest['attachments'] as List<dynamic>;
    if (matches &&
        (uploadPath == null ||
            files.any((value) => value['storage_path'] == uploadPath))) {
      return;
    }
    throw const FormatException(
      'This item changed elsewhere. Reopen it to edit the latest version.',
    );
  }

  Future<void> _discardUnlinkedUpload(String owner, String path) async {
    try {
      _requireOwner(owner);
      final linked = await _client
          .from('attachments')
          .select('id')
          .eq('user_id', owner)
          .eq('storage_path', path)
          .maybeSingle();
      if (linked == null) await _removeFiles(owner, [path]);
    } catch (_) {
      // Keep the upload when its status cannot be verified.
    }
  }

  Future<void> _removeFiles(String owner, Iterable<String> paths) async {
    final owned = paths.where((path) => path.startsWith('$owner/')).toList();
    if (owned.isEmpty || _client.auth.currentUser?.id != owner) return;
    try {
      await _client.storage.from('vault').remove(owned);
    } catch (_) {
      // The record has committed. Storage cleanup is best effort.
    }
  }

  static Map<String, Object> _editFields(ItemDraft draft) {
    final name = draft.name.trim();
    if (name.isEmpty || name.runes.length > 200) {
      throw const FormatException('Enter a title of 1 to 200 characters.');
    }
    if (draft.kind != ItemKind.bill) {
      final end = draft.coverUntil;
      if (end == null) {
        throw const FormatException('Choose when this document ends or renews.');
      }
      return {'name': name, 'end_on': isoDate(end)};
    }
    final start = draft.startsOn;
    if (start == null) throw const FormatException('Choose the purchase date.');
    return {
      'name': name,
      'purchased_on': isoDate(start),
      'warranty_months': _warrantyMonths(start, draft.coverUntil),
    };
  }

  static Map<String, Object?> arguments(String id, ItemDraft draft) {
    final bill = draft.kind == ItemKind.bill;
    final start = draft.startsOn;
    final end = draft.coverUntil;
    final amount = draft.amountMinor;
    final name = draft.name.trim();
    if (name.isEmpty) {
      throw const FormatException('Add a name so you can find it later.');
    }
    if (name.runes.length > 200 ||
        draft.source.runes.length > 200 ||
        draft.reference.runes.length > 100 ||
        draft.serialNumber.runes.length > 100 ||
        draft.notes.runes.length > 4000) {
      throw const FormatException(
        'Use up to 200 characters for the name and seller or issuer, '
        '100 for the reference and serial number, and 4,000 for notes.',
      );
    }
    if (amount != null &&
        (draft.currency != 'USD' || amount < 0 || amount > 999999999999)) {
      throw const FormatException('Enter an amount in US dollars.');
    }
    final common = {'p_id': id, 'p_name': name, 'p_notes': draft.notes};
    if (!bill) {
      if (end == null) {
        throw const FormatException(
          'Choose when this document ends or renews.',
        );
      }
      return {
        ...common,
        'p_type': draft.kind == ItemKind.agreement ? 'other' : draft.kind.name,
        'p_subtype': draft.subtype.isEmpty ? draft.kind.label : draft.subtype,
        'p_issuer': draft.source,
        'p_number': draft.reference,
        'p_start_on': start == null ? null : isoDate(start),
        'p_end_on': isoDate(end),
        'p_remind_days': 15,
        'p_amount': amount == null ? null : editableMoney(amount),
        'p_amount_per_year': draft.kind == ItemKind.policy,
      };
    }
    if (start == null) {
      throw const FormatException('Choose the purchase date.');
    }
    final returns = draft.returnUntil;
    final days = returns == null ? 0 : daysBetween(start, returns);
    if (days < 0 || days > 365) {
      throw const FormatException('Choose a return window of up to 365 days.');
    }
    final months = _warrantyMonths(start, end);
    final partEnd = draft.componentWarrantyUntil;
    final partMonths = partEnd == null ? 0 : _wholeMonths(start, partEnd);
    final part = draft.componentWarrantyName.trim();
    if (partEnd != null) {
      if (partMonths < 12 || partMonths > 600 || partMonths % 12 != 0) {
        throw const FormatException(
          'Choose component coverage in whole years, up to 50 years.',
        );
      }
      if (part.isEmpty || part.runes.length > 80) {
        throw const FormatException(
          'Enter a component name of up to 80 characters.',
        );
      }
    }
    return {
      ...common,
      'p_category': 'Other',
      'p_store': draft.source,
      'p_invoice_no': draft.reference,
      'p_serial_no': draft.serialNumber,
      'p_purchased_on': isoDate(start),
      'p_price': editableMoney(amount ?? 0),
      'p_return_days': days,
      'p_warranty_months': months,
      if (partEnd != null)
        'p_parts': [
          {'name': part, 'years': partMonths ~/ 12},
        ],
    };
  }

  static int _wholeMonths(DateTime start, DateTime end) {
    final months = (end.year - start.year) * 12 + end.month - start.month;
    return addMonths(start, months) == civil(end) ? months : -1;
  }

  static int _warrantyMonths(DateTime start, DateTime? end) {
    if (end == null) return 0;
    final months = _wholeMonths(start, end);
    if (months < 1 || months > 600) {
      throw const FormatException(
        'Choose a warranty duration in whole months, up to 50 years.',
      );
    }
    return months;
  }

  Future<Map<String, Object>> _upload(
    String owner,
    String id,
    PendingFile original,
  ) async {
    final name = p.basename(
      original.name.isEmpty ? original.path : original.name,
    );
    final extension = p.extension(name).toLowerCase();
    final mime = switch (extension) {
      '.pdf' => 'application/pdf',
      '.jpg' || '.jpeg' => 'image/jpeg',
      '.png' => 'image/png',
      '.webp' => 'image/webp',
      '.heic' => 'image/heic',
      '.heif' => 'image/heif',
      _ => null,
    };
    final file = File(original.path);
    final size = await file.exists() ? await file.length() : 0;
    if (mime == null ||
        name.runes.length > 255 ||
        size == 0 ||
        size > maxAttachmentBytes) {
      throw const FormatException(
        'Choose a readable photo or PDF up to 20 MB.',
      );
    }
    final fileId = const Uuid().v5(Namespace.url.value, '$id:${original.path}');
    final path = '$owner/mobile-items/$fileId$extension';
    _requireOwner(owner);
    try {
      await _client.storage
          .from('vault')
          .upload(path, file, fileOptions: FileOptions(contentType: mime));
    } on StorageException catch (error) {
      if (error.statusCode != '409' && error.error != 'Duplicate') rethrow;
    }
    return {
      'storage_path': path,
      'file_name': name,
      'mime_type': mime,
      'size_bytes': size,
    };
  }

  void _requireOwner(String owner) {
    if (_client.auth.currentUser?.id != owner) {
      throw const FormatException('Sign in to save this item.');
    }
  }
}
