import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:paperdrawer/ui/core/layout/pd_breakpoints.dart';
import 'package:paperdrawer/ui/core/layout/pd_columns.dart';
import 'package:paperdrawer/ui/core/layout/pd_content_width.dart';

import '../theme/pd_harness.dart';

void main() {
  test('600 pt is the first regular width', () {
    expect(PdBreakpoints.classify(599.9), PdWidthClass.compact);
    expect(PdBreakpoints.classify(600), PdWidthClass.regular);
    expect(PdWidthClass.compact.screenMargin, 20);
    expect(PdWidthClass.regular.screenMargin, 32);
  });

  test('one column under 600 pt, then two, then three on wide windows', () {
    expect(pdColumnCount(353), 1);
    expect(pdColumnCount(599), 1);
    expect(pdColumnCount(772), 2);
    expect(pdColumnCount(1100), 3);
    expect(pdColumnCount(1100, maxColumns: 2), 2);
  });

  testWidgets('the window width decides the class (iPhone 16, iPad)', (
    tester,
  ) async {
    final seen = <PdWidthClass>[];
    for (final device in PdTestDevice.values) {
      await pumpPd(
        tester,
        Builder(
          builder: (context) {
            seen.add(PdBreakpoints.of(context));
            return const SizedBox.shrink();
          },
        ),
        device: device,
      );
    }
    expect(seen, [PdWidthClass.compact, PdWidthClass.regular]);
  });

  testWidgets('reading columns cap at 680 pt on iPad', (tester) async {
    await pumpPd(
      tester,
      const PdContentWidth(
        child: SizedBox(key: ValueKey('column'), height: 10, width: 2000),
      ),
      device: PdTestDevice.iPad,
    );
    expect(tester.getSize(find.byKey(const ValueKey('column'))).width, 680);
  });

  testWidgets('cards lay out in two columns on iPad and one on iPhone', (
    tester,
  ) async {
    // On iPad the content sits beside the 344 pt sidebar column (836 pt).
    Widget grid({double sidebar = 0}) => SingleChildScrollView(
      padding: EdgeInsets.only(left: sidebar),
      child: PdColumns(
        children: [
          for (var i = 0; i < 5; i++)
            SizedBox(key: ValueKey('card-$i'), height: 80 + i * 10.0),
        ],
      ),
    );
    await pumpPd(tester, grid(sidebar: 344), device: PdTestDevice.iPad);
    final a = tester.getRect(find.byKey(const ValueKey('card-0')));
    final b = tester.getRect(find.byKey(const ValueKey('card-1')));
    final c = tester.getRect(find.byKey(const ValueKey('card-2')));
    expect(a.top, b.top);
    expect(c.left, a.left);
    expect(b.left, greaterThan(a.right));
    await pumpPd(tester, grid());
    final phoneA = tester.getRect(find.byKey(const ValueKey('card-0')));
    final phoneB = tester.getRect(find.byKey(const ValueKey('card-1')));
    expect(phoneB.top, greaterThan(phoneA.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the sliver columns build the same rows lazily', (tester) async {
    await pumpPd(
      tester,
      CustomScrollView(
        slivers: [
          PdSliverColumns(
            itemCount: 7,
            itemBuilder: (context, i) =>
                SizedBox(key: ValueKey('tile-$i'), height: 60),
          ),
        ],
      ),
      device: PdTestDevice.iPad,
    );
    expect(pdColumnCount(1180), 3);
    final first = tester.getRect(find.byKey(const ValueKey('tile-0')));
    final fourth = tester.getRect(find.byKey(const ValueKey('tile-3')));
    expect(fourth.top, greaterThan(first.top));
    expect(fourth.left, first.left);
  });
}
