import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../domain/formats.dart';
import '../../domain/models/item.dart';
import 'file_store.dart' show maxAttachmentBytes;

/// Writes a new item using the same RPCs and private bucket as the web forms.
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
    final months = end == null ? 0 : _wholeMonths(start, end);
    if (end != null && (months < 1 || months > 600)) {
      throw const FormatException(
        'Choose a warranty duration in whole months, up to 50 years.',
      );
    }
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
      throw const FormatException('Sign in to add an item to your vault.');
    }
  }
}
