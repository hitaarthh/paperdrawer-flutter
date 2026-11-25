import 'package:flutter/foundation.dart';

import '../../core/failure/app_failure.dart';
import '../../core/result/result.dart';
import 'plan_policy.dart';

/// How full the drawer is on the active plan.
///
/// One object answers every capacity question so the Add button, the Vault
/// banner, the "drawer full" screen and restoring from the archive all agree.
@immutable
sealed class ItemCapacity {
  const ItemCapacity();

  /// The capacity for [activeCount] active (not archived) items on [policy].
  factory ItemCapacity.of(PlanPolicy policy, int activeCount) {
    assert(activeCount >= 0);
    final limit = policy.itemLimit;
    if (limit == null) return const CapacityUnlimited();
    if (activeCount >= limit.max) {
      return CapacityFull(max: limit.max, planName: policy.plan.name);
    }
    if (activeCount >= limit.warnFrom) {
      return CapacityNearLimit(count: activeCount, max: limit.max);
    }
    return CapacityRoomLeft(count: activeCount, max: limit.max);
  }

  /// Ok when one more active item fits (adding, or restoring from the
  /// archive); otherwise a [LimitReachedFailure].
  Result<Unit> checkCanAdd() => switch (this) {
    CapacityFull(:final max, :final planName) => Err(
      LimitReachedFailure(limit: max, planName: planName),
    ),
    _ => const Ok(unit),
  };
}

/// No cap on this plan.
final class CapacityUnlimited extends ItemCapacity {
  const CapacityUnlimited();

  @override
  bool operator ==(Object other) => other is CapacityUnlimited;

  @override
  int get hashCode => (CapacityUnlimited).hashCode;
}

/// Under the warning threshold. The UI shows nothing.
final class CapacityRoomLeft extends ItemCapacity {
  const CapacityRoomLeft({required this.count, required this.max});

  final int count;
  final int max;

  @override
  bool operator ==(Object other) =>
      other is CapacityRoomLeft && other.count == count && other.max == max;

  @override
  int get hashCode => Object.hash(count, max);
}

/// At or past the warning threshold, still room. The UI shows "n of max".
final class CapacityNearLimit extends ItemCapacity {
  const CapacityNearLimit({required this.count, required this.max});

  final int count;
  final int max;

  int get left => max - count;

  @override
  bool operator ==(Object other) =>
      other is CapacityNearLimit && other.count == count && other.max == max;

  @override
  int get hashCode => Object.hash(count, max);
}

/// No room. Adding is blocked; the UI offers "archive or upgrade". Nothing
/// is ever deleted to make room.
final class CapacityFull extends ItemCapacity {
  const CapacityFull({required this.max, required this.planName});

  final int max;
  final String planName;

  @override
  bool operator ==(Object other) =>
      other is CapacityFull && other.max == max && other.planName == planName;

  @override
  int get hashCode => Object.hash(max, planName);
}
