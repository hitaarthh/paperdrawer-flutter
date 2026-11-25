import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrawer/core/failure/app_failure.dart';
import 'package:paperdrawer/core/result/result.dart';
import 'package:paperdrawer/core/ui/command.dart';
import 'package:paperdrawer/core/ui/view_model.dart';

class _Source extends ChangeNotifier {
  void bump() => notifyListeners();
}

class _CounterViewModel extends ViewModel {
  _CounterViewModel(_Source source) {
    listenTo(source);
  }

  int recomputed = 0;

  @override
  void onSourceChanged() => recomputed++;
}

void main() {
  group('Command', () {
    test('a second execute while running returns the same future', () async {
      final gate = Completer<Result<int>>();
      var calls = 0;
      final command = Command0<int>(() {
        calls++;
        return gate.future;
      });

      final first = command.execute();
      final second = command.execute();
      expect(command.running, isTrue);
      expect(identical(first, second), isTrue);

      gate.complete(const Ok(1));
      expect(await first, const Ok(1));
      expect(calls, 1);
      expect(command.running, isFalse);
      expect(command.completed, isTrue);
    });

    test('exposes non-silent failures only', () async {
      final failing = Command0<int>(
        () async => const Err(NotFoundFailure('item', 'x')),
      );
      await failing.execute();
      expect(failing.failure, const NotFoundFailure('item', 'x'));

      final cancelled = Command0<int>(
        () async => const Err(CancelledFailure()),
      );
      await cancelled.execute();
      expect(cancelled.failure, isNull);
    });

    test('a thrown error becomes UnexpectedFailure', () async {
      final command = Command1<String, int>((_) async => throw StateError('x'));
      final result = await command.execute('a');
      expect(result.failureOrNull, isA<UnexpectedFailure>());
      expect(command.running, isFalse);
    });

    test('clear forgets the last result', () async {
      final command = Command0<int>(() async => const Ok(1));
      await command.execute();
      command.clear();
      expect(command.result, isNull);
    });

    test('finishing after dispose does not throw', () async {
      final gate = Completer<Result<int>>();
      final command = Command0<int>(() => gate.future);
      final future = command.execute();
      command.dispose();
      gate.complete(const Ok(1));
      expect(await future, const Ok(1));
    });
  });

  group('ViewModel', () {
    test('recomputes and notifies when a source changes', () {
      final source = _Source();
      final vm = _CounterViewModel(source);
      var notified = 0;
      vm.addListener(() => notified++);

      source.bump();
      expect(vm.recomputed, 1);
      expect(notified, 1);
    });

    test('stops listening after dispose', () {
      final source = _Source();
      final vm = _CounterViewModel(source)..dispose();
      source.bump();
      expect(vm.recomputed, 0);
      expect(vm.isDisposed, isTrue);
    });
  });
}
