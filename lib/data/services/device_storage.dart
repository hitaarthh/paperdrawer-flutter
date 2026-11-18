import 'dart:io';

import 'package:flutter/services.dart';

abstract final class DeviceStorage {
  static Future<void> excludeFromBackup() async {
    if (!Platform.isIOS) return;
    await const MethodChannel('app.paperdrawer.mobile/storage')
        .invokeMethod<void>('excludeFromBackup');
  }
}
