import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrawer/data/repositories/settings_repository.dart';
import 'package:paperdrawer/data/services/account_settings_sync.dart';
import 'package:paperdrawer/data/services/app_database.dart';
import 'package:paperdrawer/domain/models/shared_profile.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late Directory root;
  late Database db;
  late SettingsRepository settings;

  Future<void> open() async {
    db = await AppDatabase.open(
      p.join(root.path, 'settings.sqlite'),
      factory: databaseFactoryFfi,
    );
    settings = SettingsRepository(db, syncsAccountSettings: true);
    await settings.load();
  }

  Future<void> close() async {
    await settings.finishWrites();
    settings.dispose();
    await db.close();
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('paperdrawer-settings-sync-');
    await open();
  });

  tearDown(() async {
    await close();
    await root.delete(recursive: true);
  });

  test(
    'offline changes survive reopening and only changed account fields sync',
    () async {
      final remote = _Remote()..offline = true;
      final sync = AccountSettingsSync(settings, remote);
      await settings.setLeadDays(7); // Default, not an edit.
      await settings.setRemindersOn(true); // Device only.
      await settings.setEmailReminders(false);
      await sync.sync();
      expect(settings.pendingSettings.keys, [SharedSetting.emailReminders]);
      sync.dispose();
      await close();
      await open();
      expect(settings.emailReminders, isFalse);
      expect(settings.remindersOn, isTrue);

      remote.offline = false;
      remote.profile = _profile(lead: 30, name: 'Clara', base: false);
      final resumed = AccountSettingsSync(settings, remote);
      addTearDown(resumed.dispose);
      await resumed.sync();
      expect(remote.writes, [
        {SharedSetting.emailReminders: '0'},
      ]);
      expect(settings.leadDays, 30);
      expect(settings.profileName, 'Clara');
      expect(settings.onBasePlan, isFalse);
      expect(settings.pendingSettings, isEmpty);
    },
  );

  test('an old acknowledgement cannot clear a newer edit', () async {
    await settings.setLeadDays(30);
    final remote = _Remote()..holdWrites = true;
    final sync = AccountSettingsSync(settings, remote);
    addTearDown(sync.dispose);
    final first = sync.sync();
    final save30 = await remote.nextWrite.future;
    expect(save30.changes, {SharedSetting.leadDays: '30'});
    await settings.setLeadDays(2);
    final secondWrite = remote.nextWrite.future;
    save30.complete();
    await first;
    final save2 = await secondWrite;
    expect(settings.leadDays, 2);
    expect(settings.pendingSettings[SharedSetting.leadDays]?.value, '2');
    expect(save2.changes, {SharedSetting.leadDays: '2'});
    save2.complete();
    await sync.sync();
    expect(settings.pendingSettings, isEmpty);
  });

  test(
    'a concurrent web edit is pulled without overwriting a pending field',
    () async {
      final remote = _Remote()
        ..beforeWrite = () =>
            _profile(email: false, name: 'Web edit', revision: 'web');
      await settings.setLeadDays(30);
      final sync = AccountSettingsSync(settings, remote);
      addTearDown(sync.dispose);
      await sync.sync();
      expect(settings.leadDays, 30);
      expect(settings.profileName, 'Web edit');
      expect(settings.emailReminders, isFalse);
      expect(settings.pendingSettings, isEmpty);
    },
  );

  test(
    'leaving a drawer stops late replies from changing its settings',
    () async {
      await settings.setLeadDays(30);
      final remote = _Remote()..holdWrites = true;
      final sync = AccountSettingsSync(settings, remote);
      final pending = sync.sync();
      final save = await remote.nextWrite.future;
      sync.dispose();
      save.complete();
      await pending;
      expect(settings.pendingSettings[SharedSetting.leadDays]?.value, '30');
      expect(settings.profileName, isNull);
    },
  );
}

RemoteProfile _profile({
  int lead = 7,
  bool email = true,
  String name = '',
  bool base = true,
  String revision = 'original',
}) => (
  profile: SharedProfile(
    name: name,
    leadDays: lead,
    emailReminders: email,
    onBasePlan: base,
  ),
  revision: revision,
);

class _Remote implements AccountSettingsRemote {
  bool offline = false;
  bool holdWrites = false;
  RemoteProfile Function()? beforeWrite;
  RemoteProfile profile = _profile();
  final writes = <Map<SharedSetting, String>>[];
  var nextWrite =
      Completer<
        ({Map<SharedSetting, String> changes, void Function() complete})
      >();

  @override
  Future<RemoteProfile?> fetch() async {
    if (offline) throw StateError('Offline');
    return profile;
  }

  @override
  Future<RemoteProfile?> save(
    RemoteProfile expected,
    Map<SharedSetting, String> changes,
  ) async {
    if (holdWrites) {
      final release = Completer<void>();
      final arrived = nextWrite;
      nextWrite = Completer();
      arrived.complete((changes: changes, complete: release.complete));
      await release.future;
    }
    if (beforeWrite case final conflict?) {
      beforeWrite = null;
      profile = conflict();
    }
    if (expected.revision != profile.revision) return null;
    writes.add(changes);
    return profile = _profile(
      lead:
          int.tryParse(changes[SharedSetting.leadDays] ?? '') ??
          profile.profile.leadDays,
      email: changes[SharedSetting.emailReminders] == null
          ? profile.profile.emailReminders
          : changes[SharedSetting.emailReminders] == '1',
      name: profile.profile.name,
      base: profile.profile.onBasePlan,
      revision: '${writes.length}',
    );
  }
}
