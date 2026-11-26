import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:paperdrawer/ui/core/glass/flat/data_row.dart';
import 'package:paperdrawer/ui/core/glass/flat/deadline_card.dart';
import 'package:paperdrawer/ui/core/glass/flat/item_card_flat.dart';
import 'package:paperdrawer/ui/core/glass/flat/list_row_flat.dart';
import 'package:paperdrawer/ui/core/glass/flat/meter_flat.dart';
import 'package:paperdrawer/ui/core/glass/flat/paper.dart';
import 'package:paperdrawer/ui/core/glass/flat/status_label.dart';
import 'package:paperdrawer/ui/core/theme/pd_colors.dart';
import 'package:paperdrawer/ui/core/theme/pd_dynamic_type.dart';

import '../theme/pd_harness.dart';

const _cardLabel =
    'Boat Airdopes 141, bill from Croma, due, return window 2 of 10 days left';
const _deadlineLabel =
    'Boat Airdopes 141, return window closes Friday, 2 days left';

Widget _gallery({VoidCallback? onCard, VoidCallback? onDeadline}) => Scaffold(
  body: SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(20, 80, 20, 120),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DeadlineCard(
          key: const ValueKey('deadline-card'),
          count: '02',
          eyebrow: 'RETURN WINDOW',
          title: 'Boat Airdopes 141',
          detail: 'Closes Fri, 27 Nov · Croma',
          remaining: 0.2,
          due: true,
          semanticLabel: _deadlineLabel,
          onPressed: onDeadline ?? () {},
        ),
        const SizedBox(height: 12),
        const DeadlineCard(
          count: 'TODAY',
          unit: null,
          eyebrow: 'POLICY RENEWAL',
          title: 'Car insurance with a long name that wraps',
          detail: 'Renews today · HDFC Ergo',
          remaining: 0,
          due: true,
          semanticLabel: 'Car insurance, policy renews today',
          paper: PdPaperKind.document,
          size: DeadlineCardSize.detail,
        ),
        const SizedBox(height: 12),
        ItemCardFlat(
          key: const ValueKey('item-card'),
          meta: 'BILL · CROMA',
          title: 'Boat Airdopes 141',
          semanticLabel: _cardLabel,
          status: const StatusLabel(
            text: 'DUE · 2 DAYS',
            tone: PdStatusTone.due,
          ),
          rows: const [
            PdDataRow('BOUGHT', '17.11.2026'),
            PdDataRow('TOTAL', '₹1,499', strong: true),
          ],
          meter: const PdMeterFlat(
            label: 'RETURN',
            countText: '2 of 10 days left',
            remaining: 0.2,
            due: true,
          ),
          onPressed: onCard ?? () {},
        ),
        const SizedBox(height: 12),
        const ItemCardFlat(
          meta: 'POLICY · HDFC ERGO',
          title: 'Car insurance',
          semanticLabel: 'Car insurance, policy from HDFC Ergo, covered',
          paper: PdPaperKind.document,
          status: StatusLabel(text: 'COVERED', tone: PdStatusTone.covered),
          rows: [
            PdDataRow('POLICY NO.', '2311 4498 0012'),
            PdDataRow('IDV', '₹4,20,000', strong: true),
          ],
          meter: PdMeterFlat(
            label: 'COVER',
            countText: '18 days left',
            remaining: 0.06,
          ),
        ),
        const SizedBox(height: 12),
        const PdMeterFlat(
          label: 'WARRANTY',
          countText: '11 of 12 months left',
          remaining: 11 / 12,
          ground: PdGround.room,
        ),
        const SizedBox(height: 12),
        PdListGroup(
          header: 'APPEARANCE',
          footer: 'System follows your iPhone.',
          children: [
            PdListRow(
              key: const ValueKey('appearance-row'),
              icon: LucideIcons.globe,
              title: 'Appearance',
              value: 'System',
              chevron: true,
              onPressed: () {},
            ),
            PdListRow(
              key: const ValueKey('delete-row'),
              icon: LucideIcons.trash2,
              title: 'Delete account',
              destructive: true,
              onPressed: () {},
            ),
          ],
        ),
      ],
    ),
  ),
);

void main() {
  testWidgets('paper components fit both themes and every text size', (
    tester,
  ) async {
    await forEachThemeAndScale(tester, (brightness, scale) async {
      await pumpPd(
        tester,
        _gallery(),
        brightness: brightness,
        textScale: scale,
      );
    });
  });

  testWidgets('paper looks the same in light and dark', (tester) async {
    Color groundOf(Finder card) => tester
        .widgetList<DecoratedBox>(
          find.descendant(of: card, matching: find.byType(DecoratedBox)),
        )
        .map((box) => box.decoration)
        .whereType<ShapeDecoration>()
        .first
        .color!;
    final grounds = <Color>[];
    for (final brightness in Brightness.values) {
      await pumpPd(tester, _gallery(), brightness: brightness);
      grounds.add(groundOf(find.byKey(const ValueKey('item-card'))));
    }
    expect(grounds, everyElement(PdColors.dark.paper));
  });

  testWidgets('each card is one VoiceOver element that opens the item', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var cards = 0;
    var deadlines = 0;
    await pumpPd(
      tester,
      _gallery(onCard: () => cards++, onDeadline: () => deadlines++),
    );
    expect(find.bySemanticsLabel(_cardLabel), findsOneWidget);
    expect(find.bySemanticsLabel(_deadlineLabel), findsOneWidget);
    expect(find.bySemanticsLabel('Appearance, System'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('item-card')));
    await tester.tap(find.byKey(const ValueKey('deadline-card')));
    await tester.pumpAndSettle();
    expect(cards, 1);
    expect(deadlines, 1);
    semantics.dispose();
  });

  testWidgets('due states use due-ink on paper and signal on the room', (
    tester,
  ) async {
    for (final brightness in Brightness.values) {
      final colors = PdColors.forBrightness(brightness);
      await pumpPd(tester, _gallery(), brightness: brightness);
      final status = tester.widget<Text>(find.text('DUE · 2 DAYS'));
      expect(status.style?.color, colors.dueInk);
      expect(
        PdStatusTone.due.colorIn(colors, PdGround.room),
        colors.signal,
      );
    }
  });

  testWidgets('at accessibility sizes the day count sits above the title', (
    tester,
  ) async {
    await pumpPd(tester, _gallery(), textScale: PdDynamicType.largestScale);
    final number = tester.getTopLeft(find.text('02'));
    final title = tester.getTopLeft(find.text('Boat Airdopes 141').first);
    expect(number.dy, lessThan(title.dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets('at the default size the day count sits beside the title', (
    tester,
  ) async {
    await pumpPd(tester, _gallery());
    final number = tester.getRect(find.text('02'));
    final title = tester.getRect(find.text('Boat Airdopes 141').first);
    expect(number.right, lessThan(title.left));
  });

  testWidgets('tappable cards and rows keep a 44 pt hit area', (tester) async {
    await pumpPd(tester, _gallery());
    for (final key in ['item-card', 'deadline-card', 'appearance-row']) {
      expect(
        tester.getSize(find.byKey(ValueKey(key))).height,
        greaterThanOrEqualTo(44),
        reason: key,
      );
    }
  });
}
