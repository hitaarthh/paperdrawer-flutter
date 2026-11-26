import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:paperdrawer/ui/core/glass/pd_glass_sheet.dart';
import 'package:paperdrawer/ui/core/glass/pd_toast.dart';

import '../theme/pd_harness.dart';

void main() {
  group('PdToastController', () {
    testWidgets('a toast without Undo hides after 4 seconds', (tester) async {
      final toasts = PdToastController(haptics: false);
      addTearDown(toasts.dispose);
      toasts.show(const PdToastMessage('Saved. First reminder on 17 Nov.'));
      await tester.pump(const Duration(milliseconds: 3900));
      expect(toasts.current, isNotNull);
      await tester.pump(const Duration(milliseconds: 200));
      expect(toasts.current, isNull);
    });

    testWidgets('a toast with Undo stays 6 seconds', (tester) async {
      final toasts = PdToastController(haptics: false);
      addTearDown(toasts.dispose);
      toasts.show(PdToastMessage('Archived.', onUndo: () {}));
      await tester.pump(const Duration(seconds: 5));
      expect(toasts.current, isNotNull);
      await tester.pump(const Duration(seconds: 1, milliseconds: 1));
      expect(toasts.current, isNull);
    });

    testWidgets('VoiceOver focus holds the toast until focus leaves', (
      tester,
    ) async {
      final toasts = PdToastController(haptics: false);
      addTearDown(toasts.dispose);
      toasts.show(const PdToastMessage('Saved.'));
      toasts.holdForAccessibility(true);
      await tester.pump(const Duration(seconds: 30));
      expect(toasts.current, isNotNull);
      toasts.holdForAccessibility(false);
      await tester.pump(const Duration(seconds: 4, milliseconds: 1));
      expect(toasts.current, isNull);
    });

    test('a new toast replaces the old one instead of stacking', () {
      final toasts = PdToastController(haptics: false);
      addTearDown(toasts.dispose);
      toasts.show(const PdToastMessage('Saved.'));
      toasts.show(const PdToastMessage('Archived.'));
      expect(toasts.current?.text, 'Archived.');
      toasts.dismiss();
    });
  });

  testWidgets('toast fits both themes and every text size and offers Undo', (
    tester,
  ) async {
    var undone = 0;
    final message = PdToastMessage(
      'Saved. First reminder on 17 Nov.',
      onUndo: () => undone++,
    );
    await forEachThemeAndScale(tester, (brightness, scale) async {
      await pumpPd(
        tester,
        Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: PdToast(message: message),
            ),
          ),
        ),
        brightness: brightness,
        textScale: scale,
      );
    });
    final semantics = tester.ensureSemantics();
    expect(find.bySemanticsLabel('Undo'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('toast-undo')));
    expect(undone, 1);
    expect(
      tester.getSize(find.byKey(const ValueKey('toast-undo'))).height,
      greaterThanOrEqualTo(44),
    );
    semantics.dispose();
  });

  Widget sheetLauncher(PdSheetDetent detent, {VoidCallback? onPrimary}) =>
      Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              key: const ValueKey('open-sheet'),
              onPressed: () => unawaited(
                showPdGlassSheet<void>(
                context,
                detent: detent,
                semanticLabel: 'Add',
                builder: (sheetContext) => PdGlassSheet(
                  title: 'What are you adding?',
                  detent: detent,
                  onClose: () => Navigator.of(sheetContext).pop(),
                  primaryAction: TextButton(
                    key: const ValueKey('sheet-primary'),
                    onPressed: onPrimary,
                    child: const Text('Take a photo'),
                  ),
                  secondaryActions: [
                    TextButton(onPressed: () {}, child: const Text('Upload')),
                    TextButton(onPressed: () {}, child: const Text('Type it')),
                  ],
                  child: const Text('Bill, warranty, policy or agreement.'),
                ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );

  testWidgets('sheet opens in both detents, themes and text sizes', (
    tester,
  ) async {
    for (final detent in PdSheetDetent.values) {
      await forEachThemeAndScale(tester, (brightness, scale) async {
        await pumpPd(
          tester,
          sheetLauncher(detent),
          brightness: brightness,
          textScale: scale,
        );
        await tester.tap(find.byKey(const ValueKey('open-sheet')));
        await tester.pumpAndSettle();
        expect(find.text('What are you adding?'), findsOneWidget);
        expect(find.byKey(const ValueKey('sheet-primary')), findsOneWidget);
      });
    }
  });

  testWidgets('sheet close button is a labelled 44 pt target that closes it', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpPd(tester, sheetLauncher(PdSheetDetent.medium));
    await tester.tap(find.byKey(const ValueKey('open-sheet')));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Close'), findsOneWidget);
    final close = find.byKey(const ValueKey('sheet-close'));
    expect(tester.getSize(close).height, greaterThanOrEqualTo(44));
    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(find.text('What are you adding?'), findsNothing);
    semantics.dispose();
  });

  testWidgets('with Reduce Motion the sheet appears without a slide', (
    tester,
  ) async {
    await pumpPd(tester, sheetLauncher(PdSheetDetent.medium), reduceMotion: true);
    await tester.tap(find.byKey(const ValueKey('open-sheet')));
    await tester.pump();
    await tester.pump();
    expect(find.text('What are you adding?'), findsOneWidget);
  });
}
