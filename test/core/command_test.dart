import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrawer/core/failure/app_failure.dart';
import 'package:paperdrawer/core/result/result.dart';
import 'package:paperdrawer/core/ui/command.dart';
import 'package:paperdrawer/core/ui/view_model.dart';
import 'package:paperdrawer/core/ui/view_state.dart';

class _Source extends ChangeNotifier {
  void bump() => notifyListeners();
}

final class _CounterViewModel extends ViewModel {
  _CounterViewModel(_Source source) {
    listenTo(source);
    save = command0(() async => const Ok(1));
  }

  late final Command0<int> save;
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

    test('a synchronous throw does not leave the command running', () async {
      final command = Command0<int>(() => throw StateError('sync bug'));
      final result = await command.execute();
      expect(result.failureOrNull, isA<UnexpectedFailure>());
      expect(command.running, isFalse);
      // And it can run again.
      expect((await command.execute()).isErr, isTrue);
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

    test('an async thrown error becomes UnexpectedFailure', () async {
      final command = Command1<String, int>((_) async => throw StateError('x'));
      final result = await command.execute('a');
      expect(result.failureOrNull, isA<UnexpectedFailure>());
      expect(command.running, isFalse);
    });

    test('Command1 with a different argument while running is refused', () async {
      final gate = Completer<Result<String>>();
      final archive = Command1<String, String>((id) => gate.future);
      final first = archive.execute('a');
      expect(identical(archive.execute('a'), first), isTrue);
      expect(await archive.execute('b'), const Err<String>(CancelledFailure()));
      gate.complete(const Ok('a'));
      expect(await first, const Ok('a'));
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

    test('a command state change notifies the view model', () async {
      final vm = _CounterViewModel(_Source());
      var notified = 0;
      vm.addListener(() => notified++);
      await vm.save.execute();
      expect(notified, greaterThanOrEqualTo(2), reason: 'start and finish');
    });

    test('stops listening and disposes commands after dispose', () {
      final source = _Source();
      final vm = _CounterViewModel(source)..dispose();
      source.bump();
      expect(vm.recomputed, 0);
      expect(vm.isDisposed, isTrue);
      expect(() => vm.notifyListeners(), returnsNormally);
    });
  });

  group('ViewState', () {
    test('keeps the last data while loading or after a failure', () {
      expect(const ViewIdle<String>().dataOrNull, isNull);
      expect(const ViewLoading<String>(previous: 'a').dataOrNull, 'a');
      expect(const ViewReady('b').dataOrNull, 'b');
      expect(
        const ViewFailed<String>(NetworkFailure(), previous: 'c').dataOrNull,
        'c',
      );
    });

    test('has value equality', () {
      expect(const ViewReady('a'), const ViewReady('a'));
      expect(const ViewReady('a'), isNot(const ViewReady('b')));
    });
  });
}
