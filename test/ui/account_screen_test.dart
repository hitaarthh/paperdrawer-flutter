import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoTextField;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:paperdrawer/data/services/shared_account.dart';
import 'package:paperdrawer/routing/shared_router.dart';
import 'package:paperdrawer/ui/core/theme/app_theme.dart';
import 'package:paperdrawer/ui/core/widgets/button.dart';
import 'package:paperdrawer/ui/features/account/shared_session.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _name = ValueKey('account-name');
const _email = ValueKey('account-email');
const _password = ValueKey('account-password');
const _submit = ValueKey('account-submit');
const _secret = 'correct horse 42';

void main() {
  testWidgets('tabs switch between sign in and create account', (tester) async {
    await _launch(tester);
    expect(find.text('Open your vault'), findsOneWidget);
    expect(find.byKey(_name), findsNothing);
    await tester.enterText(find.byKey(_email), 'asha@example.in');
    await tester.enterText(find.byKey(_password), _secret);

    await _tap(tester, const ValueKey('account-tab-create'));
    expect(find.text('Start your vault'), findsOneWidget);
    expect(
      find.text('Takes a minute. Your first item takes another.'),
      findsOneWidget,
    );
    expect(find.byKey(_name), findsOneWidget);
    expect(
      find.text('Used to verify your account and reset your password.'),
      findsOneWidget,
    );
    expect(find.text('BILLS ARE NEVER SOLD OR SHARED'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    // The email carries over; the password never does.
    expect(_text(tester, _email), 'asha@example.in');
    expect(_text(tester, _password), isEmpty);

    await _tap(tester, const ValueKey('account-tab-sign-in'));
    expect(find.text('Open your vault'), findsOneWidget);
    expect(find.byKey(_name), findsNothing);
    expect(find.byKey(const ValueKey('account-reset')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sign-up validates, then asks the user to check their email', (
    tester,
  ) async {
    final account = _FakeAccount();
    await _launch(tester, account: account, create: true);

    await _tap(tester, _submit);
    expect(
      find.textContaining('at least 8 characters for your password'),
      findsOneWidget,
    );
    await tester.enterText(find.byKey(_name), '  Asha Rao ');
    await tester.enterText(find.byKey(_email), 'asha@example.in ');
    await tester.enterText(find.byKey(_password), 'short');
    await _tap(tester, _submit);
    expect(find.byKey(const ValueKey('account-error')), findsOneWidget);
    expect(account.signUps, isEmpty);

    await tester.enterText(find.byKey(_password), _secret);
    await _tap(tester, _submit);
    expect(account.signUps, [('Asha Rao', 'asha@example.in', _secret)]);
    expect(find.text('Check your email'), findsOneWidget);
    expect(find.textContaining('asha@example.in'), findsOneWidget);
    expect(find.textContaining(_secret), findsNothing);
    expect(find.byKey(const ValueKey('account-tab-create')), findsNothing);

    await _tap(tester, const ValueKey('account-back-to-sign-in'));
    expect(find.text('Open your vault'), findsOneWidget);
    expect(_text(tester, _password), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('SHOW reveals the password and HIDE masks it again', (
    tester,
  ) async {
    await _launch(tester, create: true);
    bool obscured() =>
        tester.widget<CupertinoTextField>(find.byKey(_password)).obscureText;
    await tester.enterText(find.byKey(_password), _secret);
    expect(obscured(), isTrue);
    expect(find.text('SHOW'), findsOneWidget);

    await _tap(tester, const ValueKey('account-password-toggle'));
    expect(obscured(), isFalse);
    expect(find.text('HIDE'), findsOneWidget);
    expect(_text(tester, _password), _secret);

    await _tap(tester, const ValueKey('account-password-toggle'));
    expect(obscured(), isTrue);
    expect(find.bySemanticsLabel('Show password'), findsOneWidget);
  });

  testWidgets('field errors show after leaving the field', (tester) async {
    await _launch(tester, create: true);
    await tester.enterText(find.byKey(_email), 'asha');
    await tester.enterText(find.byKey(_password), 'short');
    await tester.tap(find.byKey(_name));
    await tester.pumpAndSettle();
    expect(find.text('Enter an email like you@example.com.'), findsOneWidget);
    expect(find.text('Use at least 8 characters.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sign-in shows busy, then redirects to the vault', (
    tester,
  ) async {
    final pending = Completer<void>();
    final account = _FakeAccount(signInResult: () => pending.future);
    await _launch(tester, account: account);
    await tester.enterText(find.byKey(_email), ' asha@example.in');
    await tester.enterText(find.byKey(_password), _secret);
    await tester.tap(find.byKey(_submit));
    await tester.pump();

    expect(tester.widget<PdButton>(find.byKey(_submit)).busy, isTrue);
    expect(
      tester.widget<CupertinoTextField>(find.byKey(_email)).enabled,
      isFalse,
    );
    expect(account.signIns, [('asha@example.in', _secret)]);

    pending.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(_submit), findsNothing);
    expect(find.text('Open your vault'), findsNothing);
    // Leave the vault cleanly: its fetch fails against the unused client.
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('auth and network failures show calm copy', (tester) async {
    Object failure = const AuthException('x', code: 'invalid_credentials');
    final account = _FakeAccount(signInResult: () => throw failure);
    await _launch(tester, account: account);
    await tester.enterText(find.byKey(_email), 'asha@example.in');
    await tester.enterText(find.byKey(_password), _secret);

    await _tap(tester, _submit);
    expect(find.text('That email or password didn’t match.'), findsOneWidget);

    failure = const AuthException('x', code: 'email_not_confirmed');
    await _tap(tester, _submit);
    expect(find.text('Check your email'), findsOneWidget);
    await _tap(tester, const ValueKey('account-resend-confirmation'));
    expect(account.confirmationRequests, ['asha@example.in']);
    expect(find.text('A new confirmation link was requested.'), findsOneWidget);
    await _tap(tester, const ValueKey('account-back-to-sign-in'));
    await tester.enterText(find.byKey(_password), _secret);

    failure = Exception('offline');
    await _tap(tester, _submit);
    expect(
      find.text(
        'Couldn’t reach Paper Drawer. Check your connection and try again.',
      ),
      findsOneWidget,
    );
    expect(tester.widget<PdButton>(find.byKey(_submit)).busy, isFalse);

    account.signUpResult = () =>
        throw const AuthException('x', code: 'email_exists');
    await _tap(tester, const ValueKey('account-tab-create'));
    expect(find.byKey(const ValueKey('account-error')), findsNothing);
    await tester.enterText(find.byKey(_name), 'Asha');
    await tester.enterText(find.byKey(_password), _secret);
    await _tap(tester, _submit);
    expect(
      find.text('An account with this email already exists. Sign in instead.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('reset, Terms and Privacy open the web pages', (tester) async {
    final session = await _launch(tester, create: true);
    await tester.ensureVisible(find.byKey(const ValueKey('account-legal')));
    await tester.pumpAndSettle();
    await tester.tapOnText(find.textRange.ofSubstring('Terms'));
    await tester.tapOnText(find.textRange.ofSubstring('Privacy policy'));
    await _tap(tester, const ValueKey('account-tab-sign-in'));
    await _tap(tester, const ValueKey('account-reset'));
    expect(session.opened, ['/terms', '/privacy', '/signin']);
    expect(tester.takeException(), isNull);
  });

  for (final create in [false, true]) {
    testWidgets('${create ? 'create account' : 'sign in'} fits at 1.3× text', (
      tester,
    ) async {
      await _launch(tester, create: create, scale: 1.3);
      final last = find.byKey(const ValueKey('account-legal'));
      await tester.ensureVisible(last);
      await tester.pumpAndSettle();
      expect(last, findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _tap(WidgetTester tester, Key key) async {
  final target = find.byKey(key);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

String _text(WidgetTester tester, Key key) =>
    tester.widget<CupertinoTextField>(find.byKey(key)).controller!.text;

Future<_FakeSession> _launch(
  WidgetTester tester, {
  _FakeAccount? account,
  bool create = false,
  double scale = 1,
}) async {
  final session = _FakeSession(account ?? _FakeAccount());
  final router = buildSharedRouter(session);
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = const Size(1179, 2556);
  tester.view.padding = const FakeViewPadding(top: 177, bottom: 102);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  addTearDown(session.dispose);
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ChangeNotifierProvider<SharedSession>.value(
      value: session,
      child: MaterialApp.router(routerConfig: router, theme: pdTheme()),
    ),
  );
  router.go(create ? '/account?mode=create' : '/account');
  await tester.pumpAndSettle();
  return session;
}

class _FakeSession extends SharedSession {
  _FakeSession(super.account);

  final opened = <String>[];

  @override
  Future<void> openWeb(String path) async => opened.add(path);
}

class _FakeAccount extends SharedAccount {
  _FakeAccount({this.signInResult})
    : super(
        _UnusedClient(),
        SharedAccountConfig(
          Uri.parse('https://example.invalid'),
          'unused',
          Uri.parse('https://example.invalid'),
        ),
      );

  Future<void> Function()? signInResult;

  /// Returns whether sign-up signed the user in; null means "check email".
  Future<bool> Function()? signUpResult;
  final signIns = <(String, String)>[];
  final signUps = <(String, String, String)>[];
  final confirmationRequests = <String>[];
  final _changes = StreamController<AuthState>.broadcast();
  User? _user;

  @override
  User? get user => _user;

  @override
  Stream<AuthState> get changes => _changes.stream;

  @override
  Future<void> signIn(String email, String password) async {
    signIns.add((email, password));
    await signInResult?.call();
    _user = const User(
      id: 'owner',
      appMetadata: {},
      userMetadata: {},
      aud: 'authenticated',
      createdAt: '2026-11-19T00:00:00Z',
    );
    _changes.add(const AuthState(AuthChangeEvent.signedIn, null));
  }

  @override
  Future<bool> signUp(String name, String email, String password) async {
    signUps.add((name, email, password));
    return await signUpResult?.call() ?? false;
  }

  @override
  Future<void> resendConfirmation(String email) async =>
      confirmationRequests.add(email);
}

class _UnusedClient implements SupabaseClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
