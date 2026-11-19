import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:paperdrawer/data/services/today.dart';
import 'package:paperdrawer/domain/models/item.dart';
import 'package:paperdrawer/domain/models/ledger.dart';
import 'package:paperdrawer/ui/core/theme/app_theme.dart';
import 'package:paperdrawer/ui/features/claims/claim_ledger_screen.dart';

void main() {
  testWidgets('adds a dated photo entry and settles the claim at 130% text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.padding = const FakeViewPadding(top: 177, bottom: 102);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final clock = Today(() => DateTime(2026, 11, 18, 9, 15));
    addTearDown(clock.dispose);
    final entries = <LedgerEntry>[];
    LedgerDraft? saved;
    String? outcome;
    DateTime? followUp;
    var openedFile = false;
    var permissionPrompts = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: pdTheme(),
        home: StatefulBuilder(
          builder: (context, update) => ClaimLedgerScreen(
            title: 'Laptop hinge repair',
            itemLabel: 'Laptop',
            opened: DateTime(2026, 11, 4),
            settled: outcome == null ? null : clock.value,
            entries: entries,
            followUp: followUp,
            clock: clock,
            serial: 'LT14-0091-ZQ',
            files: [
              (
                name: 'Bill.pdf',
                open: () async {
                  openedFile = true;
                },
              ),
            ],
            pickPhoto: () async =>
                const PendingFile(path: '/tmp/hinge.jpg', name: 'hinge.jpg'),
            addEntry: (draft) async => update(() {
              saved = draft;
              followUp = draft.followUp;
              entries.add(
                LedgerEntry(
                  id: 'refund',
                  date: draft.date,
                  kind: draft.kind,
                  text: draft.text,
                  reference: draft.reference,
                ),
              );
            }),
            setFollowUp: (when) async => update(() => followUp = when),
            enableNotifications: () async {
              permissionPrompts++;
              return true;
            },
            share: (_, _) async {},
            settle: (note) async => update(() => outcome = note),
          ),
        ),
      ),
    );

    Finder key(String id) => find.byKey(ValueKey(id));
    Future<void> tap(Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    expect(find.text('OPEN'), findsOneWidget);
    await tap(key('ledger-add-entry'));
    expect(find.text('What happened?'), findsOneWidget);
    await tap(key('ledger-kind-refund'));
    await tap(key('ledger-entry-date'));
    expect(find.text('Entry date'), findsOneWidget);
    await tap(find.text('Done'));
    await tap(key('ledger-entry-photo'));
    expect(find.text('hinge.jpg'), findsOneWidget);
    await tap(key('ledger-entry-follow-up'));
    await tap(find.text('Done'));
    await tester.enterText(
      key('ledger-entry-text'),
      'Support confirmed a refund.',
    );
    await tester.enterText(key('ledger-entry-reference'), 'SR-55821');
    await tester.pumpAndSettle();
    await tap(key('ledger-entry-save'));

    expect(saved!.kind, LedgerKind.refund);
    expect(saved!.date, DateTime.utc(2026, 11, 18));
    expect(saved!.photo!.name, 'hinge.jpg');
    expect(followUp, DateTime(2026, 11, 19, 10));
    expect(permissionPrompts, 1);
    expect(find.text('REF SR-55821'), findsOneWidget);
    expect(find.text('Support confirmed a refund.'), findsOneWidget);
    await tap(key('ledger-file-0'));
    expect(openedFile, isTrue);

    await tap(key('mark-claim-settled'));
    await tester.enterText(key('claim-log-text'), 'Refund confirmed.');
    await tap(key('save-claim-log'));
    expect(outcome, 'Refund confirmed.');
    expect(find.text('SETTLED'), findsOneWidget);
    expect(key('ledger-add-entry'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
