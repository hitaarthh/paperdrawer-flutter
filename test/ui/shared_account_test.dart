import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoTextField;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:paperdrawer/data/services/shared_account.dart';
import 'package:paperdrawer/domain/formats.dart';
import 'package:paperdrawer/domain/models/item.dart';
import 'package:paperdrawer/domain/models/shared_vault.dart';
import 'package:paperdrawer/routing/shared_router.dart';
import 'package:paperdrawer/ui/core/theme/app_theme.dart';
import 'package:paperdrawer/ui/features/account/shared_session.dart';
import 'package:paperdrawer/ui/features/account/shared_vault_screens.dart';
import 'package:paperdrawer/ui/features/vault/shared_vault_screen.dart';
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

  testWidgets('signed-in vault shows the new search, tickets, and Add sheet', (
    tester,
  ) async {
    final session = _SharedVaultSession();
    final today = session.today.value;
    session.vault = SharedVault(
      items: [
        SharedItem(
          Item(
            id: 'bill',
            createdAt: today,
            draft: ItemDraft(
              kind: ItemKind.bill,
              name: 'Headphones',
              startsOn: today,
              returnUntil: addDays(today, 2),
            ),
          ),
          const [],
          const [],
        ),
      ],
      claims: const [],
    );
    await _launchVault(tester, session);
    expect(find.text('The vault'), findsOneWidget);
    expect(find.text('1 OF 25'), findsOneWidget);
    expect(find.text('DUE NEXT'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('shared-vault-add')));
    await tester.pumpAndSettle();
    expect(find.text('What are you adding?'), findsOneWidget);
    final manual = find.byKey(const ValueKey('add-sheet-manual'));
    await tester.ensureVisible(manual);
    await tester.tap(manual);
    await tester.pumpAndSettle();
    expect(session.opened, '/bills/new');

    await tester.enterText(
      find.byKey(const ValueKey('vault-search')),
      'Laptop',
    );
    await tester.pumpAndSettle();
    expect(find.text('DUE NEXT'), findsNothing);
    expect(find.text('No matching items'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('empty shared vault opens the web add flow from the receipt', (
    tester,
  ) async {
    final session = _SharedVaultSession()
      ..vault = const SharedVault(items: [], claims: []);
    await _launchVault(tester, session);
    expect(find.text('Add the last thing you bought.'), findsOneWidget);
    final add = find.byKey(const ValueKey('scan-first-bill'));
    await tester.ensureVisible(add);
    await tester.pumpAndSettle();
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(session.opened, '/add?type=bill');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'shared Claims shows requested documents and opens the add flow',
    (tester) async {
      final session = _SharedVaultSession();
      session.vault = SharedVault(
        items: const [],
        claims: [
          SharedClaim.fromRow({
            'id': 'hospital',
            'title': 'Hospital bill reimbursement',
            'item_label': 'Family health policy',
            'type': 'insurance',
            'state': 'docs_asked',
            'step': 0,
            'opened_on': isoDate(addDays(session.today.value, -16)),
            'next_step': {
              'title': 'Upload the discharge summary',
              'text': 'Send the summary to the insurer.',
            },
          }),
        ],
      );
      _setPhoneSize(tester, 1.3);
      addTearDown(session.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: session,
          child: MaterialApp(
            theme: pdTheme(),
            home: const SharedClaimsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 OPEN · 0 SETTLED · 1 NEEDS YOU'), findsOneWidget);
      expect(find.text('NEEDS YOU · DOCUMENTS ASKED'), findsOneWidget);
      expect(find.text('STEP 1 OF 4 · INSURER OR TPA'), findsOneWidget);
      expect(find.text('DOCS ASKED'), findsOneWidget);
      expect(find.text('Next: Upload the discharge summary'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('claim-settled-filter')));
      await tester.pumpAndSettle();
      expect(find.text('No settled claims yet'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('shared-claims-scan')));
      await tester.pumpAndSettle();
      final manual = find.byKey(const ValueKey('add-sheet-manual'));
      await tester.ensureVisible(manual);
      await tester.tap(manual);
      await tester.pumpAndSettle();
      expect(session.opened, '/bills/new');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

Future<void> _launchVault(WidgetTester tester, SharedSession session) async {
  _setPhoneSize(tester, 1.3);
  addTearDown(session.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: session,
      child: MaterialApp(theme: pdTheme(), home: const SharedVaultScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _launch(WidgetTester tester, {double scale = 1.3}) async {
  final session = SharedSession(_SignedOutAccount());
  final router = buildSharedRouter(session);
  _setPhoneSize(tester, scale);
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

void _setPhoneSize(WidgetTester tester, double scale) {
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = const Size(1179, 2556);
  tester.view.padding = const FakeViewPadding(top: 177, bottom: 102);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

class _SharedVaultSession extends SharedSession {
  _SharedVaultSession() : super(_SignedOutAccount());

  String? opened;

  @override
  Future<void> openWeb(String path) async => opened = path;
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
