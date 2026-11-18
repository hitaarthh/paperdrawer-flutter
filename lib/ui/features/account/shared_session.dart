import 'dart:async';
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart' show XFile;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/services/drawer_actions.dart';
import '../../../data/services/shared_account.dart';
import '../../../data/services/shared_vault_service.dart';
import '../../../data/services/today.dart';
import '../../../domain/models/shared_profile.dart';
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
  int _accountGeneration = 0;
  String? get email => account.user?.email;
  String get displayName {
    final profileName = vault?.profile?.name;
    if (profileName != null && profileName.isNotEmpty) return profileName;
    final name = account.user?.userMetadata?['name'];
    if (name is String && name.trim().isNotEmpty) return name.trim();
    return email?.split('@').first ?? 'Paper Drawer account';
  }

  bool get signedIn => _userId != null;
  SharedVault? vault;
  bool loading = false;
  bool failed = false;
  bool savingReminders = false;
  bool _disposed = false;

  Future<void> refresh() async {
    today.refresh();
    final owner = _userId;
    if (owner == null || loading || savingReminders) return;
    final generation = _accountGeneration;
    loading = true;
    failed = false;
    notifyListeners();
    try {
      final snapshot = await _service.fetch(owner);
      if (_isCurrent(generation)) vault = snapshot;
    } catch (_) {
      if (_isCurrent(generation)) failed = true;
    } finally {
      if (_isCurrent(generation)) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> updateReminders({int? leadDays, bool? emailReminders}) async {
    final owner = _userId;
    final snapshot = vault;
    if (owner == null ||
        loading ||
        savingReminders ||
        snapshot?.profile == null) {
      return;
    }
    if (leadDays == null && emailReminders == null) return;
    if (leadDays != null && !SharedProfile.leadDayChoices.contains(leadDays)) {
      throw ArgumentError.value(leadDays, 'leadDays');
    }
    final generation = _accountGeneration;
    savingReminders = true;
    notifyListeners();
    try {
      final profile = await _service.updateReminders(
        owner,
        leadDays: leadDays,
        emailReminders: emailReminders,
      );
      if (_isCurrent(generation)) {
        vault = SharedVault(
          items: snapshot!.items,
          claims: snapshot.claims,
          profile: profile,
        );
      }
    } finally {
      if (_isCurrent(generation)) {
        savingReminders = false;
        notifyListeners();
      }
    }
  }

  bool _isCurrent(int generation) =>
      !_disposed && _accountGeneration == generation;

  void _onAccount() {
    final owner = account.user?.id;
    final previous = _userId;
    if (owner == previous) return;
    _userId = owner;
    _accountGeneration++;
    vault = null;
    loading = false;
    failed = false;
    savingReminders = false;
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

  Future<String?> appVersion() => _actions.appVersion();

  Future<Uint8List?> previewOriginal(SharedOriginal original) async {
    final owner = _userId;
    if (owner == null || !original.mime.startsWith('image/')) return null;
    final data = await _service.fetchOriginal(owner, original);
    return !_disposed && owner == _userId ? data : null;
  }

  Future<void> shareOriginal(SharedOriginal original, {Rect? origin}) async {
    final owner = _userId;
    if (owner == null) return;
    final file = await _service.download(owner, original);
    if (_disposed || owner != _userId) return;
    await _actions.shareFiles([
      XFile(file.path, name: original.name),
    ], origin: origin);
  }

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
