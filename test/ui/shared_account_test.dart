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
  testWidgets('shared vault starts at sign-in and offers account creation', (
    tester,
  ) async {
    final origin = Uri.parse('https://example.invalid');
    final client = SupabaseClient(
      origin.toString(),
      'test-publishable-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    final session = SharedSession(
      SharedAccount(client, SharedAccountConfig(origin, 'unused', origin)),
    );
    final router = buildSharedRouter(session);
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.padding = const FakeViewPadding(top: 177, bottom: 102);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(client.dispose);
    addTearDown(session.dispose);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: session,
        child: MaterialApp.router(routerConfig: router, theme: pdTheme()),
      ),
    );
    await tester.pumpAndSettle();
    final password = find.byKey(const ValueKey('account-password'));
    expect(tester.widget<CupertinoTextField>(password).obscureText, isTrue);
    expect(find.text('Sign in'), findsOneWidget);

    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('account-name')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('account-submit')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('at least 8 characters for your password'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
