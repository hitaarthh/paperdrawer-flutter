import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:paperdrawer/core/result/result.dart';
import 'package:paperdrawer/core/failure/app_failure.dart';
import 'package:paperdrawer/ui/core/glass/glass_scope.dart';
import 'package:paperdrawer/domain/settings/appearance.dart';
import 'package:paperdrawer/ui/core/theme/pd_dynamic_type.dart';
import 'package:paperdrawer/ui/core/theme/pd_theme.dart';

/// Screen sizes from AGENTS §9 and the iPad board.
enum PdTestDevice {
  /// iPhone 16: 1179×2556 at 3×, padding top 177, bottom 102 (physical).
  iPhone16,

  /// iPad landscape, 1180×820 pt at 2×, status bar 24 pt, home indicator
  /// 20 pt.
  iPad,
}

/// Text scales every widget test runs at: default, the AGENTS 1.3× check
/// and the largest accessibility size.
const pdTestScales = [1.0, 1.3, PdDynamicType.largestScale];

void pdSetDevice(WidgetTester tester, PdTestDevice device) {
  switch (device) {
    case PdTestDevice.iPhone16:
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3;
      tester.view.padding = const FakeViewPadding(top: 177, bottom: 102);
    case PdTestDevice.iPad:
      tester.view.physicalSize = const Size(2360, 1640);
      tester.view.devicePixelRatio = 2;
      tester.view.padding = const FakeViewPadding(top: 48, bottom: 40);
  }
  addTearDown(tester.view.reset);
}

/// Pumps [child] in the PaperDrawer theme with the given accessibility
/// settings. Native glass is off (tests run the Flutter glass).
Future<void> pumpPd(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.dark,
  PdTestDevice device = PdTestDevice.iPhone16,
  double textScale = 1,
  bool reduceTransparency = false,
  bool highContrast = false,
  bool reduceMotion = false,
  bool settle = true,
}) async {
  pdSetDevice(tester, device);
  await tester.pumpWidget(
    MaterialApp(
      // A fresh app per pump, so routes (sheets) never leak between runs.
      key: UniqueKey(),
      theme: pdThemeData(brightness),
      debugShowCheckedModeBanner: false,
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          highContrast: highContrast,
          disableAnimations: reduceMotion,
        ),
        child: PdGlassScope(
          reduceTransparency: reduceTransparency,
          nativeGlass: false,
          child: app ?? const SizedBox.shrink(),
        ),
      ),
      home: child,
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

/// Runs [body] for both themes and every text scale, failing on any layout
/// overflow.
Future<void> forEachThemeAndScale(
  WidgetTester tester,
  Future<void> Function(Brightness brightness, double scale) body,
) async {
  for (final brightness in Brightness.values) {
    for (final scale in pdTestScales) {
      await body(brightness, scale);
      expect(
        tester.takeException(),
        isNull,
        reason: 'overflow in ${brightness.name} at ${scale}x',
      );
    }
  }
}

/// An in-memory [AppearanceStore] (fake, no mocking library).
final class FakeAppearanceStore implements AppearanceStore {
  FakeAppearanceStore([this.stored]);

  AppearanceMode? stored;
  AppFailure? failReads;
  AppFailure? failWrites;
  int writes = 0;
  final _Changes _changes = _Changes();

  /// Simulates a change from settings sync.
  void changeElsewhere(AppearanceMode mode) {
    stored = mode;
    _changes.fire();
  }

  @override
  Listenable get changes => _changes;

  @override
  Future<Result<AppearanceMode>> read() async {
    final failure = failReads;
    if (failure != null) return Err<AppearanceMode>(failure);
    return Ok(stored ?? AppearanceMode.system);
  }

  @override
  Future<Result<Unit>> write(AppearanceMode mode) async {
    writes++;
    final failure = failWrites;
    if (failure != null) return Err<Unit>(failure);
    stored = mode;
    return const Ok(unit);
  }
}

final class _Changes extends ChangeNotifier {
  void fire() => notifyListeners();
}
