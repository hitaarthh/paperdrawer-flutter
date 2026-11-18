import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/services/drawer_actions.dart';
import '../../../data/services/shared_account.dart';
import '../../../data/services/shared_vault_service.dart';
import '../../../data/services/today.dart';
import '../../../domain/models/shared_vault.dart';

class SharedSession extends ChangeNotifier {
  SharedSession(this.account) : _service = SharedVaultService(account.client) {
    _subscription = account.changes.listen(
      (_) => _onAccount(),
      onError: (Object _, StackTrace _) => _onAccount(),
    );
    _onAccount();
  }

  final SharedAccount account;
  final SharedVaultService _service;
  late final StreamSubscription<AuthState> _subscription;
  final Today today = Today();
  final _actions = const DrawerActions();
  String? _userId;
  String? get email => account.user?.email;
  bool get signedIn => _userId != null;
  SharedVault? vault;
  bool loading = false;
  bool failed = false;
  bool _disposed = false;

  Future<void> refresh() async {
    today.refresh();
    final owner = _userId;
    if (owner == null || loading) return;
    loading = true;
    failed = false;
    notifyListeners();
    try {
      final snapshot = await _service.fetch(owner);
      if (!_disposed && _userId == owner) vault = snapshot;
    } catch (_) {
      if (!_disposed && _userId == owner) failed = true;
    } finally {
      if (!_disposed && _userId == owner) {
        loading = false;
        notifyListeners();
      }
    }
  }

  void _onAccount() {
    final owner = account.user?.id;
    final previous = _userId;
    if (owner == previous) return;
    _userId = owner;
    vault = null;
    loading = false;
    failed = false;
    notifyListeners();
    if (previous != null) unawaited(_clearDownloads(previous));
    if (owner != null) unawaited(refresh());
  }

  Future<void> _clearDownloads(String userId) async {
    try {
      await _service.clearDownloads(userId);
    } catch (_) {
      // The OS can reclaim this temporary cache.
    }
  }

  Future<void> openWeb(String path) =>
      _actions.openLink(account.config.web.resolve(path));

  Future<void> openOriginal(SharedOriginal original) async {
    final owner = _userId;
    if (owner == null) return;
    final file = await _service.download(owner, original);
    if (_disposed || owner != _userId) return;
    final result = await OpenFilex.open(file.path, type: original.mime);
    if (result.type != ResultType.done) {
      throw const FormatException('This original couldn’t open.');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription.cancel());
    if (_userId case final userId?) unawaited(_clearDownloads(userId));
    today.dispose();
    super.dispose();
  }
}
