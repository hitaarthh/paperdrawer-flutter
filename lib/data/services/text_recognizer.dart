import 'package:flutter/services.dart';

abstract interface class TextRecognizer {
  Future<List<String>> recognize(String path);
}

class PlatformTextRecognizer implements TextRecognizer {
  const PlatformTextRecognizer();

  static const _channel = MethodChannel('app.paperdrawer.mobile/text');

  @override
  Future<List<String>> recognize(String path) async {
    try {
      return await _channel.invokeListMethod<String>('recognize', {
            'path': path,
          }) ??
          const [];
    } catch (_) {
      return const [];
    }
  }
}

class FakeTextRecognizer implements TextRecognizer {
  const FakeTextRecognizer(this.lines);

  final List<String> lines;

  @override
  Future<List<String>> recognize(String path) async => lines;
}
