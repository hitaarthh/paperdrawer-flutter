import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../domain/formats.dart';
import '../../domain/models/shared_profile.dart';
import '../../domain/models/shared_vault.dart';

class SharedVaultService {
  const SharedVaultService(this._client);
  final SupabaseClient _client;

  static const _files = 'attachments(file_name,storage_path,mime_type)';
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
      _page(
        'claims',
        '*,claim_events(title,note,occurred_on,created_at),$_files',
        userId,
        'opened_on',
      ),
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
