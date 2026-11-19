import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:paperdrawer/ui/core/theme/app_theme.dart';
import 'package:paperdrawer/ui/core/theme/type.dart';
import 'package:paperdrawer/ui/features/intro/art/claim_art.dart';

const _art = Key('claim-art');

Future<void> _loadFont(String family, String path) async {
  final bytes = File(path).readAsBytesSync();
  final loader = FontLoader(family)
    ..addFont(Future.value(ByteData.sublistView(bytes)));
  await loader.load();
}

Widget _canvas({TextScaler textScaler = TextScaler.noScaling}) => MaterialApp(
  theme: pdTheme(),
  debugShowCheckedModeBanner: false,
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
      child: const ColoredBox(
        color: Color(0xFF0E1311),
        child: Center(
          child: SizedBox(
            width: 390,
            height: 360,
            child: RepaintBoundary(key: _art, child: ClaimArt()),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  setUpAll(() async {
    await _loadFont(PdType.sans, 'assets/fonts/Inter.ttf');
    await _loadFont(PdType.mono, 'assets/fonts/JetBrainsMono.ttf');
  });

  testWidgets('draws the sample claim ledger within the art canvas', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_canvas());

    expect(tester.takeException(), isNull);
    for (final text in [
      'Laptop hinge repair',
      'OPEN',
      'FOLLOW UP SAT 21 NOV',
      'CLAIM LEDGER',
      'Support booked a repair visit.',
      'Sent the invoice and a photo of the hinge.',
    ]) {
      expect(find.text(text), findsOneWidget);
    }

    // The content-driven card fits the 360px canvas.
    final canvas = tester.getRect(find.byType(ClaimArt));
    final card = tester.getRect(
      find
          .descendant(
            of: find.byType(ClaimArt),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect(card.bottom, lessThanOrEqualTo(canvas.bottom));

    await expectLater(
      find.byKey(_art),
      matchesGoldenFile('goldens/claim_art.png'),
    );
  });

  testWidgets('ignores Dynamic Type', (tester) async {
    await tester.pumpWidget(_canvas(textScaler: const TextScaler.linear(2)));

    expect(tester.takeException(), isNull);
    final title = tester.getSize(find.text('Support booked a repair visit.'));
    await tester.pumpWidget(_canvas());
    expect(tester.getSize(find.text('Support booked a repair visit.')), title);
  });
}
