import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoTextField;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:paperdrawer/data/services/shared_account.dart';
import 'package:paperdrawer/routing/shared_router.dart';
import 'package:paperdrawer/ui/core/theme/app_theme.dart';
import 'package:paperdrawer/ui/features/account/shared_session.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('intro steps through Keep, Remember, Claim to account creation', (
    tester,
  ) async {
    await _launch(tester, scale: 1);
    expect(find.text('Keep it.'), findsOneWidget);
    expect(find.bySemanticsLabel('Step 1 of 3'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('intro-next')));
    await tester.pumpAndSettle();
    expect(find.text('Remember it.'), findsOneWidget);
    expect(find.bySemanticsLabel('Step 2 of 3'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('intro-next')));
    await tester.pumpAndSettle();
    expect(find.text('Claim it.'), findsOneWidget);
    expect(find.byKey(const ValueKey('intro-skip')), findsNothing);

    await tester.tap(find.text('Start your vault'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('account-name')), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('intro skips to account creation at 200% text', (tester) async {
    await _launch(tester, scale: 2);
    await tester.tap(find.byKey(const ValueKey('intro-skip')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('account-name')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('shared vault starts at sign-in and offers account creation', (
    tester,
  ) async {
    await _launch(tester);
    expect(find.text('Keep it.'), findsOneWidget);
    final existing = find.byKey(const ValueKey('intro-sign-in'));
    await tester.ensureVisible(existing);
    await tester.tap(existing);
    await tester.pumpAndSettle();
    final password = find.byKey(const ValueKey('account-password'));
    expect(tester.widget<CupertinoTextField>(password).obscureText, isTrue);
    expect(find.text('Sign in'), findsOneWidget);

    final create = find.byKey(const ValueKey('account-tab-create'));
    await tester.ensureVisible(create);
    await tester.pumpAndSettle();
    await tester.tap(create);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('account-name')), findsOneWidget);
    final submit = find.byKey(const ValueKey('account-submit'));
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('at least 8 characters for your password'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Future<void> _launch(WidgetTester tester, {double scale = 1.3}) async {
  final session = SharedSession(_SignedOutAccount());
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
    ChangeNotifierProvider.value(
      value: session,
      child: MaterialApp.router(
        routerConfig: router,
        theme: pdTheme(),
        // Same Dynamic Type cap as the app.
        builder: (context, child) {
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(
              textScaler: media.textScaler.clamp(maxScaleFactor: 2),
            ),
            child: child!,
          );
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _SignedOutAccount extends SharedAccount {
  _SignedOutAccount()
    : super(
        _UnusedClient(),
        SharedAccountConfig(
          Uri.parse('https://example.invalid'),
          'unused',
          Uri.parse('https://example.invalid'),
        ),
      );

  @override
  User? get user => null;

  @override
  Stream<AuthState> get changes => const Stream.empty();
}

class _UnusedClient implements SupabaseClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
