import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrawer/core/failure/app_failure.dart';
import 'package:paperdrawer/core/failure/validation_issue.dart';
import 'package:paperdrawer/core/result/result.dart';

void main() {
  const failure = NotFoundFailure('item', 'a');

  group('Result', () {
    test('Ok exposes its value and no failure', () {
      const result = Result<int>.ok(3);
      expect(result.isOk, isTrue);
      expect(result.valueOrNull, 3);
      expect(result.failureOrNull, isNull);
      expect(result.requireValue, 3);
    });

    test('Err exposes its failure and no value', () {
      const result = Result<int>.err(failure);
      expect(result.isErr, isTrue);
      expect(result.valueOrNull, isNull);
      expect(result.failureOrNull, failure);
      expect(() => result.requireValue, throwsStateError);
    });

    test('map transforms Ok and passes Err through', () {
      expect(const Ok(2).map((v) => v * 10), const Ok(20));
      expect(
        const Err<int>(failure).map((v) => v * 10),
        const Err<int>(failure),
      );
    });

    test('flatMap chains and short-circuits', () {
      Result<int> half(int v) => v.isEven
          ? Ok(v ~/ 2)
          : const Err(ValidationFailure(ValidationIssue.amountInvalid));
      expect(const Ok(8).flatMap(half), const Ok(4));
      expect(const Ok(3).flatMap(half).isErr, isTrue);
      expect(const Err<int>(failure).flatMap(half), const Err<int>(failure));
    });

    test('andThen awaits the next step only on Ok', () async {
      var called = false;
      Future<Result<String>> next(int v) async {
        called = true;
        return Ok('$v');
      }

      expect(await const Ok(1).andThen(next), const Ok('1'));
      called = false;
      expect(
        await const Err<int>(failure).andThen(next),
        const Err<String>(failure),
      );
      expect(called, isFalse);
    });

    test('fold collapses both branches', () {
      String show(Result<int> r) =>
          r.fold(ok: (v) => 'ok $v', err: (_) => 'err');
      expect(show(const Ok(1)), 'ok 1');
      expect(show(const Err(failure)), 'err');
    });

    test('unit is a single comparable value', () {
      expect(const Ok(unit), const Ok(unit));
    });
  });
}
