import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:paperdrawer/data/services/shared_account.dart';
import 'package:paperdrawer/data/services/shared_vault_service.dart';
import 'package:paperdrawer/domain/models/shared_profile.dart';
import 'package:paperdrawer/domain/models/shared_vault.dart';
import 'package:paperdrawer/routing/shared_router.dart';
import 'package:paperdrawer/ui/core/theme/app_theme.dart';
import 'package:paperdrawer/ui/core/widgets/meter.dart';
import 'package:paperdrawer/ui/features/account/shared_session.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('shared Settings reads and saves the account reminder settings', (
    tester,
  ) async {
    final (session, service) = await _openSettings(tester);
    expect(find.text('Alex River'), findsOneWidget);
    expect(find.text('AR'), findsOneWidget);
    await _tap(tester, 'settings-plan');
    expect(find.text('0 OF 25 ITEMS'), findsOneWidget);
    expect(tester.widget<MeterBar>(find.byType(MeterBar)).fraction, 0);
    await _tap(tester, 'back-button');
    await _tap(tester, 'settings-open-notifications');
    expect(
      find.text('Bill reminders appear in Notifications.'),
      findsOneWidget,
    );

    await _tap(tester, 'shared-settings-lead-7');
    expect(service.writes, isEmpty);
    await _tap(tester, 'shared-settings-lead-2');
    expect(service.writes, [(2, null)]);
    expect(session.vault!.profile!.leadDays, 2);

    service.rejectWrite = true;
    await tester.tap(find.byKey(const ValueKey('shared-settings-lead-30')));
    await tester.pump();
    expect(
      find.text('Couldn’t save reminder settings. Try again.'),
      findsOneWidget,
    );
    expect(session.vault!.profile!.leadDays, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'the full Settings page scrolls at 130% text and opens web flows',
    (tester) async {
      final (session, _) = await _openSettings(tester, scale: 1.3);
      final heading = tester.getTopLeft(find.text('Settings'));
      expect(find.text('Paper Drawer'), findsOneWidget);
      expect(find.byKey(const ValueKey('drawer-notifications')), findsNothing);
      await _tap(tester, 'settings-open-notifications');
      expect(
        find.text('Bill reminders appear in Notifications.'),
        findsOneWidget,
      );
      await _tap(tester, 'back-button');
      await _tap(tester, 'settings-data');
      await _tap(tester, 'shared-settings-export');
      expect(session.webPaths.last, '/settings#data');
      await _tap(tester, 'shared-settings-delete');
      expect(session.webPaths.last, '/delete-account');
      await _tap(tester, 'back-button');
      await _tap(tester, 'settings-legal');
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('Terms of Service'), findsOneWidget);
      expect(find.text('Open-source licenses'), findsOneWidget);
      expect(find.text('Paper Drawer website'), findsOneWidget);
      await _tap(tester, 'back-button');
      expect(find.text('Version 0.1.0'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _tap(tester, 'vault-tab');
      expect(find.text('Your drawer'), findsOneWidget);
      final drawerHeading = tester.getTopLeft(find.text('Your drawer'));
      expect(heading.dx, drawerHeading.dx);
      expect(heading.dy, closeTo(drawerHeading.dy, 4));
      await _tap(tester, 'settings-tab');
      await _tap(tester, 'settings-account');
      await _tap(tester, 'account-sign-out');
      expect(find.text('Keep it.'), findsOneWidget);
    },
  );
}

Future<void> _tap(WidgetTester tester, String name) async {
  final target = find.byKey(ValueKey(name));
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<(_Session, _VaultService)> _openSettings(
  WidgetTester tester, {
  double scale = 1,
}) async {
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = const Size(1179, 2556);
  tester.view.padding = const FakeViewPadding(top: 177, bottom: 102);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  final account = _Account();
  final service = _VaultService();
  final session = _Session(account, service);
  final router = buildSharedRouter(session);
  addTearDown(() async {
    router.dispose();
    session.dispose();
    await account.events.close();
  });
  await tester.pumpWidget(
    ChangeNotifierProvider<SharedSession>.value(
      value: session,
      child: MaterialApp.router(theme: pdTheme(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  await _tap(tester, 'settings-tab');
  return (session, service);
}

class _Session extends SharedSession {
  _Session(super.account, _VaultService service) : super(service: service);

  final webPaths = <String>[];

  @override
  Future<String?> appVersion() async => '0.1.0';

  @override
  Future<void> openWeb(String path) async => webPaths.add(path);
}

class _VaultService extends SharedVaultService {
  _VaultService() : super(_UnusedClient());

  final writes = <(int?, bool?)>[];
  bool rejectWrite = false;
  var _profile = const SharedProfile(
    name: 'Alex River',
    leadDays: 7,
    emailReminders: true,
    onBasePlan: true,
  );

  @override
  Future<SharedVault> fetch(String userId) async =>
      SharedVault(items: const [], claims: const [], profile: _profile);

  @override
  Future<SharedProfile> updateReminders(
    String userId, {
    int? leadDays,
    bool? emailReminders,
  }) async {
    writes.add((leadDays, emailReminders));
    if (rejectWrite) throw StateError('Could not save');
    return _profile = SharedProfile(
      name: _profile.name,
      leadDays: leadDays ?? _profile.leadDays,
      emailReminders: emailReminders ?? _profile.emailReminders,
      onBasePlan: _profile.onBasePlan,
    );
  }

  @override
  Future<void> clearDownloads(String userId) async {}
}

class _Account extends SharedAccount {
  _Account()
    : super(
        _UnusedClient(),
        SharedAccountConfig(
          Uri.parse('https://example.invalid'),
          'unused',
          Uri.parse('https://example.invalid'),
        ),
      );

  final events = StreamController<AuthState>();
  bool _signedIn = true;

  @override
  User? get user => _signedIn
      ? const User(
          id: 'account',
          appMetadata: {},
          userMetadata: {'name': 'Auth Name'},
          aud: '',
          email: 'alex@example.invalid',
          createdAt: '',
        )
      : null;

  @override
  Stream<AuthState> get changes => events.stream;

  @override
  Future<void> signOut() async {
    _signedIn = false;
    events.add(const AuthState(AuthChangeEvent.signedOut, null));
  }
}

class _UnusedClient implements SupabaseClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
