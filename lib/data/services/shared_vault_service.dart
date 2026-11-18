import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/shared_vault.dart';

class SharedVaultService {
  const SharedVaultService(this._client);
  final SupabaseClient _client;

  static const _files = 'attachments(file_name,storage_path,mime_type)';

  Future<SharedVault> fetch(String userId) async {
    final profile = _client.from('profiles').select('plan').eq('id', userId).maybeSingle();
    final rows = await Future.wait([
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
    ]);
    return SharedVault(
      items: [
        ...rows[0].map(SharedItem.bill),
        ...rows[1].map(SharedItem.document),
      ],
      claims: rows[2].map(SharedClaim.fromRow).toList(),
      onBasePlan: (await profile)?['plan'] != 'pro',
    );
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

  Future<File> download(String userId, SharedOriginal original) async {
    if (_client.auth.currentUser?.id != userId ||
        !original.path.startsWith('$userId/')) {
      throw const FormatException('Sign in to open this original.');
    }
    final data = await _client.storage.from('vault').download(original.path);
    if (_client.auth.currentUser?.id != userId) {
      throw const FormatException('Sign in to open this original.');
    }
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
