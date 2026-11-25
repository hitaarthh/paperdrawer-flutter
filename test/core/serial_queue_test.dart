import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrawer/core/concurrency/serial_queue.dart';

void main() {
  test('runs operations one at a time in submission order', () async {
    final queue = SerialQueue();
    final log = <String>[];
    final first = Completer<void>();

    final a = queue.run(() async {
      log.add('a start');
      await first.future;
      log.add('a end');
      return 1;
    });
    final b = queue.run(() async {
      log.add('b');
      return 2;
    });

    await Future<void>.delayed(Duration.zero);
    expect(log, ['a start']);
    expect(queue.pending, 2);

    first.complete();
    expect(await a, 1);
    expect(await b, 2);
    expect(log, ['a start', 'a end', 'b']);
    expect(queue.pending, 0);
  });

  test('a failing operation does not block the next one', () async {
    final queue = SerialQueue();
    final failing = queue.run<int>(() async => throw StateError('boom'));
    final next = queue.run(() async => 'ok');

    await expectLater(failing, throwsStateError);
    expect(await next, 'ok');
  });

  test('close waits for queued work, then refuses new work', () async {
    final queue = SerialQueue();
    var finished = false;
    unawaited(
      queue.run(() async {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        finished = true;
      }),
    );

    await queue.close();
    expect(finished, isTrue);
    expect(queue.isClosed, isTrue);
    expect(() => queue.run(() async {}), throwsStateError);
  });
}
