import 'dart:async';
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart' show XFile;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/services/capture_service.dart';
import '../../../data/services/drawer_actions.dart';
import '../../../data/services/exporter.dart';
import '../../../data/services/shared_account.dart';
import '../../../data/services/shared_claim_reminders.dart';
import '../../../data/services/shared_vault_service.dart';
import '../../../data/services/today.dart';
import '../../../domain/models/shared_profile.dart';
import '../../../domain/models/shared_vault.dart';
import '../../../domain/models/ledger.dart';
import '../../../domain/models/item.dart';

class SharedSession extends ChangeNotifier {
  SharedSession(this.account, {SharedVaultService? service, CaptureService capture = const CaptureService()})
    : _service = service ?? SharedVaultService(account.client), _capture = capture {
    _subscription = account.changes.listen(
      (_) => _onAccount(),
      onError: (Object _, StackTrace _) => _onAccount(),
    );
    _onAccount();
  }

  final SharedAccount account;
  final SharedVaultService _service;
  final CaptureService _capture;
  late final StreamSubscription<AuthState> _subscription;
  final Today today = Today();
  final followUps = SharedClaimReminders();
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
  bool settlingClaim = false;
  bool savingLedger = false;
  bool get claimBusy => loading || savingReminders || settlingClaim || savingLedger;
  bool _disposed = false;

  Future<void> refresh() async {
    today.refresh();
    final owner = _userId;
    if (owner == null || claimBusy) return;
    final generation = _accountGeneration;
    loading = true;
    failed = false;
    notifyListeners();
    try {
      final snapshot = await _service.fetch(owner);
      if (_isCurrent(generation)) {
        vault = snapshot;
        _syncFollowUps();
      }
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
    final current = snapshot?.profile;
    if (owner == null ||
        snapshot == null ||
        current == null ||
        claimBusy) {
      return;
    }
    if (leadDays == current.leadDays) leadDays = null;
    if (emailReminders == current.emailReminders) emailReminders = null;
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
          items: snapshot.items,
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

  Future<bool> settleClaim(String id, String outcome) async {
    final owner = _userId;
    final snapshot = vault;
    final claim = snapshot?.claims.where((claim) => claim.id == id).firstOrNull;
    if (owner == null ||
        snapshot == null ||
        claim == null ||
        claim.settled != null ||
        claimBusy) {
      return false;
    }
    final note = outcome.trim();
    if (note.runes.length > 2000) {
      throw const FormatException(
        'Keep the outcome to 2,000 characters or fewer.',
      );
    }

    final generation = _accountGeneration;
    settlingClaim = true;
    notifyListeners();
    try {
      final date = await _service.settleClaim(owner, id, note);
      if (!_isCurrent(generation)) return false;
      vault = SharedVault(
        items: snapshot.items,
        claims: [
          for (final item in snapshot.claims)
            item.id == id ? SharedClaim.withSettlement(item, date) : item,
        ],
        profile: snapshot.profile,
      );
      _syncFollowUps();
      return true;
    } finally {
      if (_isCurrent(generation)) {
        settlingClaim = false;
        unawaited(refresh());
      }
    }
  }

  Future<SharedClaim> openLedger(SharedItem item) =>
      _saveLedger((owner) => _service.openLedger(owner, item));

  Future<SharedClaim> addLedgerEntry(String id, LedgerDraft entry) =>
      _saveLedger((owner) => _service.addLedgerEntry(owner, id, entry, today.instant));

  Future<SharedClaim> setFollowUp(String id, DateTime? value) =>
      _saveLedger((owner) => _service.setFollowUp(owner, id, value, today.instant));

  Future<SharedClaim> _saveLedger(
    Future<SharedClaim> Function(String owner) save,
  ) async {
    final owner = _userId;
    final snapshot = vault;
    if (owner == null || snapshot == null || claimBusy) {
      throw const FormatException('The vault is busy. Try again in a moment.');
    }
    final generation = _accountGeneration;
    savingLedger = true;
    notifyListeners();
    try {
      final claim = await save(owner);
      if (!_isCurrent(generation)) {
        throw const FormatException('Sign in to see this claim.');
      }
      vault = SharedVault(
        items: snapshot.items,
        claims: [claim, ...snapshot.claims.where((other) => other.id != claim.id)],
        profile: snapshot.profile,
      );
      _syncFollowUps();
      return claim;
    } finally {
      if (_isCurrent(generation)) {
        savingLedger = false;
        notifyListeners();
      }
    }
  }

  Future<void> shareFiles(List<XFile> files, Rect? origin) =>
      _actions.shareFiles(files, origin: origin);

  Future<PendingFile?> pickLedgerPhoto() => _capture.pickLedgerPhoto();

  Future<void> shareClaimKit(SharedItem item, Rect? origin) async {
    final owner = _userId;
    if (owner == null) return;
    final generation = _accountGeneration;
    final files = <XFile>[];
    for (final original in item.originals) {
      final file = await _service.download(owner, original);
      if (!_isCurrent(generation)) return;
      files.add(XFile(file.path, name: original.name, mimeType: original.mime));
    }
    files.add(Exporter.claimKitSummary(item.item));
    await shareFiles(files, origin);
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
    settlingClaim = false;
    savingLedger = false;
    if (previous != null) _syncFollowUps();
    notifyListeners();
    if (previous != null) unawaited(_clearDownloads(previous));
    if (owner != null) unawaited(refresh());
  }

  void _syncFollowUps() => followUps.sync(vault?.claims ?? [], today.instant);

  Future<bool> enableFollowUpNotifications() async {
    final allowed = await followUps.requestPermission();
    if (!_disposed && allowed) _syncFollowUps();
    return allowed;
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
    followUps.dispose();
    today.dispose();
    super.dispose();
  }
}
