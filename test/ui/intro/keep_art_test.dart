import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:paperdrawer/ui/core/theme/app_theme.dart';
import 'package:paperdrawer/ui/core/theme/tokens.dart';
import 'package:paperdrawer/ui/core/theme/type.dart';
import 'package:paperdrawer/ui/features/intro/art/keep_art.dart';

Future<void> _loadMono() async {
  final bytes = File('assets/fonts/JetBrainsMono.ttf').readAsBytesSync();
  final loader = FontLoader(PdType.mono)
    ..addFont(Future.value(ByteData.sublistView(bytes)));
  await loader.load();
}

const _artKey = ValueKey('keep-art');

Widget _canvas() => MaterialApp(
  theme: pdTheme(),
  debugShowCheckedModeBanner: false,
  home: const Align(
    alignment: Alignment.topLeft,
    child: RepaintBoundary(
      key: _artKey,
      child: ColoredBox(
        color: Pd.bg,
        child: SizedBox(width: 390, height: 360, child: KeepArt()),
      ),
    ),
  ),
);

void main() {
  setUpAll(_loadMono);

  testWidgets('KeepArt lays out on the 390x360 intro canvas', (tester) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(390 * 2, 360 * 2);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_canvas());

    expect(tester.takeException(), isNull);
    expect(find.text('SHARMA ELECTRONICS'), findsOneWidget);
    expect(find.text('FILED'), findsOneWidget);
    expect(find.text('POLICY SCHEDULE'), findsOneWidget);

    await expectLater(
      find.byKey(_artKey),
      matchesGoldenFile('goldens/keep_art.png'),
    );
  });

  testWidgets('KeepArt ignores Dynamic Type', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(_canvas());

    expect(tester.takeException(), isNull);
    final context = tester.element(find.text('FILED'));
    expect(MediaQuery.textScalerOf(context), TextScaler.noScaling);
  });
}
