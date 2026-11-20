import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:paperdrawer/data/repositories/settings_repository.dart';
import 'package:paperdrawer/data/services/account_settings_sync.dart';
import 'package:paperdrawer/data/services/drawer_storage.dart';
import 'package:paperdrawer/data/services/shared_account.dart';
import 'package:paperdrawer/domain/models/item.dart';
import 'package:paperdrawer/ui/features/account/shared_app.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _project = Uri.parse('https://paperdrawer.example.test');
const _clara = '11111111-1111-1111-1111-111111111111';
const _john = '22222222-2222-2222-2222-222222222222';

void main() {
  sqfliteFfiInit();

  testWidgets(
    'signed-in Add works before sync and returning accounts reopen their drawers',
    (tester) async {
      tester.view.devicePixelRatio = 3;
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.padding = const FakeViewPadding(top: 177, bottom: 102);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.runAsync(() async {
        final root = await Directory.systemTemp.createTemp(
          'paperdrawer-local-ui-',
        );
        final storage = DrawerStorage(root, factory: databaseFactoryFfi);
        for (final (id, title) in [
          (_clara, 'Clara’s bill'),
          (_john, 'John’s bill'),
        ]) {
          final drawer = await storage.open(owner: DrawerOwner(_project, id));
          await drawer.items.create(
            ItemDraft(kind: ItemKind.bill, name: title),
          );
          await drawer.close();
        }
        final account = _Account()..select('clara');
        final remote = _BlockedRemote();
        try {
          await tester.pumpWidget(
            AccountDrawerApp(
              account: account,
              storage: storage,
              settingsRemote: (_, _) => remote,
            ),
          );
          await _waitFor(tester, _key('scan-or-add'));
          expect(remote.requested, isTrue);
          await _tap(tester, _key('scan-or-add'));
          expect(find.text('Add a file'), findsOneWidget);
          await _tap(tester, _key('close-button'));
          await _tap(tester, _key('vault-tab'));
          expect(find.text('Clara’s bill'), findsOneWidget);
          expect(find.text('John’s bill'), findsNothing);

          await _signOut(tester);
          await _signIn(tester, 'john');
          await _tap(tester, _key('vault-tab'));
          expect(find.text('John’s bill'), findsOneWidget);
          expect(find.text('Clara’s bill'), findsNothing);

          await _signOut(tester);
          await _signIn(tester, 'clara');
          await _tap(tester, _key('vault-tab'));
          expect(find.text('Clara’s bill'), findsOneWidget);
          expect(find.text('John’s bill'), findsNothing);
          expect(tester.takeException(), isNull);
        } finally {
          remote.release.complete(null);
          await tester.pumpWidget(const SizedBox.shrink());
          await account.events.close();
          await account.client.dispose();
          await root.delete(recursive: true);
        }
      });
    },
  );
}

Finder _key(String value) => find.byKey(ValueKey(value));

Future<void> _waitFor(WidgetTester tester, Finder finder) async {
  final timeout = Stopwatch()..start();
  do {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  } while (timeout.elapsed < const Duration(seconds: 5));
  expect(finder, findsOneWidget);
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _signOut(WidgetTester tester) async {
  await _tap(tester, _key('settings-tab'));
  await _tap(tester, _key('settings-account'));
  expect(tester.takeException(), isNull);
  final button = _key('account-sign-out');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await _waitFor(tester, find.text('I already have an account'));
  await tester.pumpAndSettle();
}

Future<void> _signIn(WidgetTester tester, String name) async {
  await _tap(tester, find.text('I already have an account'));
  await tester.enterText(_key('account-email'), '$name@example.test');
  await tester.enterText(_key('account-password'), 'test-password');
  final submit = _key('account-submit');
  await tester.ensureVisible(submit);
  await tester.tap(submit);
  await _waitFor(tester, _key('scan-or-add'));
  await tester.pumpAndSettle();
}

class _BlockedRemote implements AccountSettingsRemote {
  final release = Completer<RemoteProfile?>();
  bool requested = false;

  @override
  Future<RemoteProfile?> fetch() {
    requested = true;
    return release.future;
  }

  @override
  Future<RemoteProfile?> save(
    RemoteProfile expected,
    Map<SharedSetting, String> changes,
  ) => throw StateError('The network is unavailable.');
}

class _Account extends SharedAccount {
  _Account()
    : super(
        SupabaseClient(
          _project.toString(),
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
        SharedAccountConfig(_project, 'test-key', _project),
      );

  @override
  User? user;
  final events = StreamController<AuthState>.broadcast();

  @override
  Stream<AuthState> get changes => events.stream;

  void select(String name) {
    user = User(
      id: name == 'clara' ? _clara : _john,
      email: '$name@example.test',
      appMetadata: const {},
      userMetadata: {'name': name},
      aud: 'authenticated',
      createdAt: '2026-11-20',
    );
    events.add(const AuthState(AuthChangeEvent.signedIn, null));
  }

  @override
  Future<void> signIn(String email, String password) async =>
      select(email.split('@').first);

  @override
  Future<void> signOut() async {
    user = null;
    events.add(const AuthState(AuthChangeEvent.signedOut, null));
  }
}
