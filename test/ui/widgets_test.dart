import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:paperdrawer/domain/item_status.dart';
import 'package:paperdrawer/domain/models/claim.dart';
import 'package:paperdrawer/domain/models/item.dart';
import 'package:paperdrawer/ui/core/theme/app_theme.dart';
import 'package:paperdrawer/ui/core/widgets/button.dart';
import 'package:paperdrawer/ui/core/widgets/chips.dart';
import 'package:paperdrawer/ui/core/widgets/claim_ladder.dart';
import 'package:paperdrawer/ui/core/widgets/countdown_ticket.dart';
import 'package:paperdrawer/ui/core/widgets/item_card.dart';
import 'package:paperdrawer/ui/core/widgets/limit_notice.dart';
import 'package:paperdrawer/ui/core/widgets/list_row.dart';
import 'package:paperdrawer/ui/core/widgets/nav.dart';
import 'package:paperdrawer/ui/core/widgets/sheets.dart';
import 'package:paperdrawer/ui/core/widgets/stamp.dart';
import 'package:paperdrawer/ui/core/widgets/tab_bar.dart';
import 'package:paperdrawer/ui/core/widgets/text_field.dart';

void main() {
  final now = DateTime(2026, 11, 18);
  final draft = ItemDraft(
    kind: ItemKind.bill,
    name: 'Long name for an item with more text than fits on one line',
    source: 'Gupta Home Appliances at the long address',
    startsOn: DateTime(2026, 11, 1),
    returnUntil: DateTime(2026, 11, 20),
    coverUntil: DateTime(2026, 12, 10),
    amountMinor: 3800000,
  );
  final item = Item(id: '1', draft: draft, createdAt: now);
  final summary = ItemSummary.of(item, now);
  final claim = Claim(
    id: '1',
    type: ClaimType.repair,
    want: ClaimWant.repair,
    itemLabel: draft.name,
    problem: 'Does not power on',
    openedOn: now,
    step: 1,
    stepSince: now,
  );

  Future<void> root(WidgetTester tester, Widget child, double scale) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(top: 177, bottom: 102);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: pdTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: child,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('dock fits narrow and wide layouts and clears the keyboard', (
    tester,
  ) async {
    await root(
      tester,
      Scaffold(
        bottomNavigationBar: PdTabBar(
          currentIndex: 0,
          onTap: (_) {},
          onScan: () {},
        ),
      ),
      1.3,
    );
    final scan = find.byKey(const ValueKey('scan-or-add'));
    tester.view.physicalSize = const Size(960, 1920);
    await tester.pumpAndSettle();
    expect(tester.getSize(scan).shortestSide, greaterThanOrEqualTo(48));
    expect(tester.getRect(scan).right, lessThan(320));
    expect(tester.getRect(scan).bottom, lessThan(640 - 34));
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(2400, 1920);
    await tester.pumpAndSettle();
    final controls = tester
        .getRect(find.byKey(const ValueKey('home-tab')))
        .expandToInclude(
          tester.getRect(find.byKey(const ValueKey('settings-tab'))),
        );
    expect(controls.width, lessThanOrEqualTo(440));
    expect(controls.center.dx, 400);

    tester.view.viewInsets = const FakeViewPadding(bottom: 864);
    await tester.pumpAndSettle();
    expect(scan, findsNothing);
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pumpAndSettle();
    expect(scan, findsOneWidget);
  });

  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets('card, countdown, large header, tabs and chip row at $scale', (
      tester,
    ) async {
      var tapped = false;
      var dismissed = false;
      await root(
        tester,
        Scaffold(
          body: PdLargeTitleScaffold(
            title: 'Vault',
            trailing: ScanButton(onTap: () {}),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList.list(
                  children: [
                    CountdownTicket(
                      summary: summary,
                      window: summary.shown!,
                      onTap: () {},
                      onDismissed: () => dismissed = true,
                    ),
                    PdChipRow(
                      children: [
                        PdFilterChip(
                          label: 'Covered',
                          count: 30,
                          selected: true,
                          onTap: () {},
                        ),
                        PdFilterChip(
                          label: 'In claim',
                          count: 10,
                          selected: false,
                          onTap: () {},
                        ),
                      ],
                    ),
                    ItemCard(summary: summary, onTap: () => tapped = true),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: PdTabBar(
            currentIndex: 0,
            onTap: (_) {},
            onScan: () {},
          ),
        ),
        scale,
      );
      expect(tester.takeException(), isNull);
      expect(find.bySemanticsLabel('Home'), findsOneWidget);
      final ticket = find.byType(CountdownTicket);
      await tester.timedDrag(
        ticket,
        const Offset(-300, 0),
        const Duration(milliseconds: 120),
      );
      await tester.pumpAndSettle();
      expect(dismissed, isTrue);
      final card = find.byType(ItemCard);
      await tester.scrollUntilVisible(
        card,
        120,
        scrollable: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(summary.semanticLabel), findsOneWidget);
      expect(find.bySemanticsLabel('DUE'), findsNothing);
      await tester.tap(card);
      expect(tapped, isTrue);
      expect(tester.takeException(), isNull);
    });
    testWidgets('push, paper form, list row and sheets at $scale', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await root(
        tester,
        Builder(
          builder: (context) => PdPushedScaffold(
            backLabel: 'Vault',
            title: 'Start a claim',
            actions: [
              PdNavIcon(
                icon: const Icon(Icons.add),
                semanticLabel: 'add',
                onTap: () {},
              ),
              PdNavIcon(
                icon: const Icon(Icons.delete),
                semanticLabel: 'more',
                onTap: () {},
              ),
            ],
            bottom: PdButton.primary(
              label: 'Show sheet',
              onPressed: () => showPdSheet<String>(
                context,
                title: 'Add to your drawer',
                subtitle: 'Choose how to add a document.',
                options: [
                  const PdSheetOption(
                    icon: Icons.camera,
                    title: 'Scan with camera',
                    description: 'Take photos of one or more pages.',
                    value: 'scan',
                    recommended: true,
                  ),
                  const PdSheetOption(
                    icon: Icons.file_open,
                    title: 'Upload a photo or PDF',
                    description: 'Use a file from your device.',
                    value: 'file',
                  ),
                ],
              ),
            ),
            children: [
              ClaimLadder(claim: claim, today: now),
              PdListGroup(
                header: 'Reminders',
                children: [
                  PdListRow(
                    title: 'Notify me before a deadline',
                    value: '7 days before ending',
                    onTap: () {},
                    chevron: true,
                    trailing: PdSwitch(value: true, onChanged: (_) {}),
                  ),
                ],
              ),
              Wrap(
                children: [
                  PdChoiceChip(label: 'Repair', selected: true, onTap: () {}),
                  PdChoiceChip(label: 'Refund', selected: false, onTap: () {}),
                ],
              ),
              PdTextField(
                label: 'Amount paid',
                controller: controller,
                readFromBill: true,
                validator: (text) => text.isEmpty ? 'Required' : null,
              ),
              LimitNotice(count: 25, onReview: () {}, onWaitlist: () {}),
              const PdStamp(StampKind.settled),
            ],
          ),
        ),
        scale,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Show sheet'));
      await tester.pumpAndSettle();
      expect(find.text('Scan with camera'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Scan with camera'));
      await tester.pumpAndSettle();
      expect(find.text('Scan with camera'), findsNothing);
    });
  }
}
