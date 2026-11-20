import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/shared_profile.dart';
import '../repositories/settings_repository.dart';

typedef RemoteProfile = ({SharedProfile profile, String revision});

abstract interface class AccountSettingsRemote {
  Future<RemoteProfile?> fetch();
  Future<RemoteProfile?> save(
    RemoteProfile expected,
    Map<SharedSetting, String> changes,
  );
}

class SupabaseAccountSettings implements AccountSettingsRemote {
  const SupabaseAccountSettings(this._client, this._owner);

  static const _fields =
      'display_name,reminder_lead_days,email_reminders,plan,updated_at';
  final SupabaseClient _client;
  final String _owner;

  bool get _isOwner => _client.auth.currentUser?.id == _owner;

  @override
  Future<RemoteProfile?> fetch() async {
    if (!_isOwner) return null;
    final row = await _client
        .from('profiles')
        .select(_fields)
        .eq('id', _owner)
        .maybeSingle();
    return _read(row);
  }

  @override
  Future<RemoteProfile?> save(
    RemoteProfile expected,
    Map<SharedSetting, String> changes,
  ) async {
    if (!_isOwner) return null;
    final patch = {
      if (changes[SharedSetting.leadDays] case final value?)
        'reminder_lead_days': int.parse(value),
      if (changes[SharedSetting.emailReminders] case final value?)
        'email_reminders': value == '1',
    };
    final row = await _client
        .from('profiles')
        .update(patch)
        .eq('id', _owner)
        .eq('updated_at', expected.revision)
        .select(_fields)
        .maybeSingle();
    return _read(row);
  }

  RemoteProfile? _read(Map<String, dynamic>? row) => !_isOwner || row == null
      ? null
      : (
          profile: SharedProfile.fromRow(row),
          revision: row['updated_at'] as String,
        );
}

/// Reconciles one open drawer with its account profile. Drawer data never
/// enters this service.
class AccountSettingsSync {
  AccountSettingsSync(this._settings, this._remote) {
    _settings.addListener(_onLocalChange);
  }

  final SettingsRepository _settings;
  final AccountSettingsRemote _remote;
  Future<void>? _running;
  Timer? _timer;
  bool _retryAfterWrite = false;
  bool _closed = false;

  void resume() {
    if (_closed) return;
    _timer ??= Timer.periodic(
      const Duration(minutes: 5),
      (_) => unawaited(sync()),
    );
    unawaited(sync());
  }

  void pause() {
    _timer?.cancel();
    _timer = null;
  }

  void _onLocalChange() {
    if (_settings.pendingSettings.isEmpty) return;
    if (_running != null) {
      _retryAfterWrite = true;
    } else {
      unawaited(sync());
    }
  }

  Future<void> sync() {
    if (_closed) return Future.value();
    return _running ??= _reconcile().whenComplete(() {
      _running = null;
      if (_retryAfterWrite && !_closed) {
        _retryAfterWrite = false;
        unawaited(sync());
      }
    });
  }

  Future<void> _reconcile() async {
    try {
      for (var attempt = 0; attempt < 2; attempt++) {
        final remote = await _remote.fetch();
        if (_closed || remote == null) return;
        final pending = _settings.pendingSettings;
        final changes = <SharedSetting, String>{
          for (final entry in pending.entries)
            if (entry.value.value != _remoteValue(remote.profile, entry.key))
              entry.key: entry.value.value,
        };
        final confirmed = changes.isEmpty
            ? remote
            : await _remote.save(remote, changes);
        if (_closed) return;
        if (confirmed == null) continue; // Another writer changed the profile.
        await _settings.mergeProfile(confirmed.profile, acknowledged: pending);
        return;
      }
    } catch (_) {
      // Keep pending edits on disk during an outage or an expired session.
    }
  }

  String _remoteValue(SharedProfile profile, SharedSetting field) =>
      switch (field) {
        SharedSetting.leadDays => profile.leadDays.toString(),
        SharedSetting.emailReminders => profile.emailReminders ? '1' : '0',
      };

  void dispose() {
    if (_closed) return;
    _closed = true;
    pause();
    _settings.removeListener(_onLocalChange);
  }
}
