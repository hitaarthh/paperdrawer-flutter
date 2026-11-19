import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../domain/formats.dart';
import '../../domain/models/item.dart';
import '../../domain/models/ledger.dart';
import '../../domain/models/shared_profile.dart';
import '../../domain/models/shared_vault.dart';
import 'file_store.dart' show maxAttachmentBytes;

class SharedVaultService {
  const SharedVaultService(this._client);
  final SupabaseClient _client;

  static const _files = 'attachments(file_name,storage_path,mime_type)';
  static const _claimFields = '*,claim_events(*),$_files';
  static const _profileFields =
      'display_name,reminder_lead_days,email_reminders,plan';

  Future<SharedVault> fetch(String userId) async {
    final (bills, documents, claims, profile) = await (
      _page(
        'bills',
        '*,bill_parts(name,years),$_files',
        userId,
        'purchased_on',
      ),
      _page('documents', '*,$_files', userId, 'end_on'),
      _page('claims', _claimFields, userId, 'opened_on'),
      _fetchProfile(userId),
    ).wait;
    return SharedVault(
      items: [
        ...bills.map(SharedItem.bill),
        ...documents.map(SharedItem.document),
      ],
      claims: claims.map(SharedClaim.fromRow).toList(),
      profile: profile,
    );
  }

  Future<SharedProfile?> _fetchProfile(String userId) async {
    final row = await _client
        .from('profiles')
        .select(_profileFields)
        .eq('id', userId)
        .maybeSingle();
    return row == null ? null : SharedProfile.fromRow(row);
  }

  Future<SharedProfile> updateReminders(
    String userId, {
    int? leadDays,
    bool? emailReminders,
  }) async {
    final row = await _client
        .from('profiles')
        .update({
          'reminder_lead_days': ?leadDays,
          'email_reminders': ?emailReminders,
        })
        .eq('id', userId)
        .select(_profileFields)
        .single();
    return SharedProfile.fromRow(row);
  }

  Future<DateTime> settleClaim(String userId, String id, String outcome) async {
    if (_client.auth.currentUser?.id != userId) {
      throw const FormatException('Sign in to settle this claim.');
    }
    final date = await _client.rpc<Object?>(
      'settle_claim',
      params: {'p_id': id, 'p_outcome': outcome},
    );
    return parseIsoDate(date) ?? (throw StateError('Missing settlement date'));
  }

  Future<SharedClaim> openLedger(String userId, SharedItem item) async {
    _requireOwner(userId);
    final id = await _client.rpc<String>(
      'open_claim_ledger',
      params: {
        'p_id': const Uuid().v4(),
        'p_item_id': item.item.id,
        'p_bill': item.item.kind == ItemKind.bill,
      },
    );
    return _fetchClaim(userId, id);
  }

  Future<SharedClaim> setFollowUp(
    String userId,
    String id,
    DateTime? followUp,
    DateTime now,
  ) async {
    _requireOwner(userId);
    validateFollowUp(followUp, now);
    await _client.rpc<void>(
      'set_claim_follow_up',
      params: {'p_id': id, 'p_at': followUp?.toUtc().toIso8601String()},
    );
    return _fetchClaim(userId, id);
  }

  Future<SharedClaim> addLedgerEntry(
    String userId,
    String id,
    LedgerDraft entry,
    DateTime now,
  ) async {
    _requireOwner(userId);
    entry.validate(now);
    final eventId = entry.id ?? const Uuid().v4();
    if (await _hasEvent(userId, id, eventId)) return _fetchClaim(userId, id);

    final photo = entry.photo;
    final attachment = photo == null
        ? null
        : await _uploadLedgerPhoto(userId, eventId, photo);
    try {
      _requireOwner(userId);
      await _client.rpc<void>(
        'add_claim_ledger_entry',
        params: {
          'p_id': id,
          'p_event_id': eventId,
          'p_on': isoDate(entry.date),
          'p_kind': entry.kind.name,
          'p_note': entry.text,
          'p_reference': entry.reference,
          'p_at': entry.followUp?.toUtc().toIso8601String(),
          'p_photo': attachment,
        },
      );
    } on PostgrestException catch (error) {
      // A server rejection rolls the transaction back. A network error may
      // have happened after commit, so a retry checks the same event ID.
      if (attachment != null &&
          error.code != null &&
          error.code!.length == 5 &&
          !await _hasEvent(userId, id, eventId)) {
        await _client.storage.from('vault').remove([
          attachment['storage_path']! as String,
        ]);
      }
      rethrow;
    }
    return _fetchClaim(userId, id);
  }

  Future<bool> _hasEvent(String userId, String claimId, String eventId) async {
    _requireOwner(userId);
    return await _client
            .from('claim_events')
            .select('id')
            .eq('user_id', userId)
            .eq('claim_id', claimId)
            .eq('id', eventId)
            .maybeSingle() !=
        null;
  }

  Future<Map<String, Object>> _uploadLedgerPhoto(
    String userId,
    String eventId,
    PendingFile picked,
  ) async {
    final name = p.basename(picked.name.isEmpty ? picked.path : picked.name);
    final extension = p.extension(name).toLowerCase();
    final mime = switch (extension) {
      '.jpg' || '.jpeg' => 'image/jpeg',
      '.png' => 'image/png',
      '.webp' => 'image/webp',
      '.heic' => 'image/heic',
      '.heif' => 'image/heif',
      _ => null,
    };
    final file = File(picked.path);
    final size = await file.exists() ? await file.length() : 0;
    if (mime == null || size == 0 || size > maxAttachmentBytes) {
      throw const FormatException('Choose a photo up to 20 MB.');
    }
    final path = '$userId/claim-ledger/$eventId$extension';
    _requireOwner(userId);
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

  Future<SharedClaim> _fetchClaim(String userId, String id) async {
    _requireOwner(userId);
    final row = await _client
        .from('claims')
        .select(_claimFields)
        .eq('user_id', userId)
        .eq('id', id)
        .single();
    _requireOwner(userId);
    return SharedClaim.fromRow(row);
  }

  void _requireOwner(String userId) {
    if (_client.auth.currentUser?.id != userId) {
      throw const FormatException('Sign in to update this claim.');
    }
  }

  Future<List<Map<String, dynamic>>> _page(
    String table,
    String selection,
    String userId,
    String ordering,
  ) async {
    const size = 100;
    final rows = <Map<String, dynamic>>[];
    while (true) {
      final page = await _client
          .from(table)
          .select(selection)
          .eq('user_id', userId)
          .order(ordering, ascending: false)
          .order('id')
          .range(rows.length, rows.length + size - 1);
      rows.addAll(page);
      if (page.length < size) return rows;
    }
  }

  Future<Uint8List> fetchOriginal(
    String userId,
    SharedOriginal original,
  ) async {
    if (_client.auth.currentUser?.id != userId ||
        !original.path.startsWith('$userId/')) {
      throw const FormatException('Sign in to open this original.');
    }
    final data = await _client.storage.from('vault').download(original.path);
    if (_client.auth.currentUser?.id != userId) {
      throw const FormatException('Sign in to open this original.');
    }
    return data;
  }

  Future<File> download(String userId, SharedOriginal original) async {
    final data = await fetchOriginal(userId, original);
    final cache = await getTemporaryDirectory();
    final folder = Directory(p.join(cache.path, 'paperdrawer-shared', userId));
    await folder.create(recursive: true);
    final file = File(
      p.join(folder.path, '${const Uuid().v4()}-${p.basename(original.name)}'),
    );
    await file.writeAsBytes(data, flush: true);
    if (_client.auth.currentUser?.id != userId) {
      await file.delete();
      throw const FormatException('Sign in to open this original.');
    }
    return file;
  }

  Future<void> clearDownloads(String userId) async {
    final cache = await getTemporaryDirectory();
    final folder = Directory(p.join(cache.path, 'paperdrawer-shared', userId));
    if (await folder.exists()) await folder.delete(recursive: true);
  }
}
