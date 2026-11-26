import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:paperdrawer/core/failure/app_failure.dart';
import 'package:paperdrawer/core/result/result.dart';
import 'package:paperdrawer/domain/settings/appearance.dart';
import 'package:paperdrawer/ui/core/theme/theme_controller.dart';

import 'pd_harness.dart';

void main() {
  const writeFailed = StorageFailure(StorageFailureKind.writeFailed);

  test('appearance defaults to System before anything is loaded', () {
    final controller = ThemeController(store: FakeAppearanceStore());
    addTearDown(controller.dispose);
    expect(controller.mode, AppearanceMode.system);
    expect(controller.themeMode, ThemeMode.system);
    expect(
      controller.brightnessFor(Brightness.light),
      Brightness.light,
    );
  });

  test('loading applies the stored choice', () async {
    final controller = ThemeController(
      store: FakeAppearanceStore(AppearanceMode.dark),
    );
    addTearDown(controller.dispose);
    final result = await controller.load.execute();
    expect(result, const Ok(AppearanceMode.dark));
    expect(controller.themeMode, ThemeMode.dark);
    expect(controller.brightnessFor(Brightness.light), Brightness.dark);
  });

  test('a failed load keeps System and reports the failure', () async {
    final store = FakeAppearanceStore(AppearanceMode.light)
      ..failReads = const StorageFailure(StorageFailureKind.unreadable);
    final controller = ThemeController(store: store);
    addTearDown(controller.dispose);
    final result = await controller.load.execute();
    expect(result.isErr, isTrue);
    expect(controller.mode, AppearanceMode.system);
    expect(controller.load.failure, isA<StorageFailure>());
  });

  test('choosing Light applies at once and saves it', () async {
    final store = FakeAppearanceStore();
    final controller = ThemeController(store: store);
    addTearDown(controller.dispose);
    var notified = 0;
    controller.addListener(() => notified++);
    final pending = controller.select.execute(AppearanceMode.light);
    expect(controller.mode, AppearanceMode.light);
    expect(await pending, const Ok(unit));
    expect(store.stored, AppearanceMode.light);
    expect(controller.themeMode, ThemeMode.light);
    expect(notified, greaterThan(0));
  });

  test('a failed save puts the previous choice back', () async {
    final store = FakeAppearanceStore(AppearanceMode.dark)
      ..failWrites = writeFailed;
    final controller = ThemeController(store: store);
    addTearDown(controller.dispose);
    await controller.load.execute();
    final result = await controller.select.execute(AppearanceMode.light);
    expect(result, const Err<Unit>(writeFailed));
    expect(controller.mode, AppearanceMode.dark);
    expect(controller.select.failure, writeFailed);
    expect(store.stored, AppearanceMode.dark);
  });

  test('a change synced from another device is picked up', () async {
    final store = FakeAppearanceStore();
    final controller = ThemeController(store: store);
    addTearDown(controller.dispose);
    store.changeElsewhere(AppearanceMode.dark);
    await pumpEventQueue();
    expect(controller.mode, AppearanceMode.dark);
  });

  test('stored values round-trip and unknown values read as System', () {
    for (final mode in AppearanceMode.values) {
      expect(AppearanceMode.fromStorage(mode.storageValue), mode);
    }
    expect(AppearanceMode.fromStorage(null), AppearanceMode.system);
    expect(AppearanceMode.fromStorage('sepia'), AppearanceMode.system);
  });
}
