import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrawer/core/failure/app_failure.dart';
import 'package:paperdrawer/core/result/result.dart';
import 'package:paperdrawer/domain/plans/item_capacity.dart';
import 'package:paperdrawer/domain/plans/plan.dart';
import 'package:paperdrawer/domain/plans/plan_policy.dart';

void main() {
  final base = PlanPolicy.of(Plan.base);

  test('Base: quiet below 20', () {
    expect(ItemCapacity.of(base, 0), const CapacityRoomLeft(count: 0, max: 25));
    expect(ItemCapacity.of(base, 19), const CapacityRoomLeft(count: 19, max: 25));
  });

  test('Base: warns from 20 to 24', () {
    final at20 = ItemCapacity.of(base, 20);
    expect(at20, const CapacityNearLimit(count: 20, max: 25));
    expect((at20 as CapacityNearLimit).left, 5);
    expect(ItemCapacity.of(base, 24), const CapacityNearLimit(count: 24, max: 25));
  });

  test('Base: full at 25 and beyond (e.g. after a downgrade)', () {
    expect(ItemCapacity.of(base, 25), const CapacityFull(max: 25, planName: 'base'));
    expect(ItemCapacity.of(base, 40), const CapacityFull(max: 25, planName: 'base'));
  });

  test('checkCanAdd blocks only when full', () {
    expect(ItemCapacity.of(base, 24).checkCanAdd(), const Ok(unit));
    expect(
      ItemCapacity.of(base, 25).checkCanAdd(),
      const Err<Unit>(LimitReachedFailure(limit: 25, planName: 'base')),
    );
  });

  test('paid plans are unlimited', () {
    for (final plan in [Plan.essential, Plan.pro]) {
      final capacity = ItemCapacity.of(PlanPolicy.of(plan), 10000);
      expect(capacity, const CapacityUnlimited());
      expect(capacity.checkCanAdd(), const Ok(unit));
    }
  });
}
