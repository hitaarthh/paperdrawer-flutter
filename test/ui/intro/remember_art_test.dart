import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:paperdrawer/ui/core/theme/app_theme.dart';
import 'package:paperdrawer/ui/core/theme/type.dart';
import 'package:paperdrawer/ui/features/intro/art/remember_art.dart';

const _art = Key('remember-art');

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
            child: RepaintBoundary(key: _art, child: RememberArt()),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  setUpAll(() async {
    await _loadFont(PdType.display, 'assets/fonts/BricolageGrotesque.ttf');
    await _loadFont(PdType.sans, 'assets/fonts/Inter.ttf');
    await _loadFont(PdType.mono, 'assets/fonts/JetBrainsMono.ttf');
  });

  void useArtView(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('draws two tickets and a reminder within the art canvas', (
    tester,
  ) async {
    useArtView(tester);
    await tester.pumpWidget(_canvas());

    expect(tester.takeException(), isNull);
    for (final text in [
      '02',
      '12',
      'RETURN WINDOW CLOSES · FRI',
      'Wireless earbuds',
      'Start the return now.',
      'POLICY RENEWS · 30 NOV',
      'Family health policy',
      'Renew before it lapses.',
      'REMINDER · 7 DAYS BEFORE',
      'Washing machine warranty ends 10 Dec',
    ]) {
      expect(find.text(text), findsOneWidget);
    }
    expect(find.text('DAYS'), findsNWidgets(2));

    // The reminder card sits at the mockup's y=270 and inside the canvas.
    final canvas = tester.getRect(find.byType(RememberArt));
    final card = tester.getRect(
      find
          .descendant(
            of: find.byType(RememberArt),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect(card.top - canvas.top, 270);
    expect(card.width, 350);
    expect(card.bottom, lessThanOrEqualTo(canvas.bottom));

    await expectLater(
      find.byKey(_art),
      matchesGoldenFile('goldens/remember_art.png'),
    );
  });

  testWidgets('ignores Dynamic Type', (tester) async {
    useArtView(tester);
    await tester.pumpWidget(_canvas(textScaler: const TextScaler.linear(3)));

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.text('Wireless earbuds')).height, lessThan(60));
  });
}
