import 'package:flutter/foundation.dart';

import 'plan.dart';
import 'plan_policy.dart';

/// One step the app takes when the plan or the account changes.
///
/// There is deliberately no "delete local data" step. A plan change can
/// start or stop syncing and change what the website shows; it can never
/// remove anything from the phone (spec: "No plan change ever deletes data on
/// the user's phone"). Because the type has no such value, no code path can
/// ask for it.
@immutable
sealed class PlanChangeStep {
  const PlanChangeStep();
}

/// The user must sign in first, with one of [methods].
final class RequireSignIn extends PlanChangeStep {
  const RequireSignIn(this.methods);

  final Set<SignInMethod> methods;

  @override
  bool operator ==(Object other) =>
      other is RequireSignIn && setEquals(other.methods, methods);

  @override
  int get hashCode => Object.hashAllUnordered(methods);
}

/// Ask "Move these n items into your account?". No keeps them in the guest
/// drawer; nothing is lost either way.
final class OfferMoveGuestItems extends PlanChangeStep {
  const OfferMoveGuestItems();

  @override
  bool operator ==(Object other) => other is OfferMoveGuestItems;

  @override
  int get hashCode => (OfferMoveGuestItems).hashCode;
}

/// Drain, then stop the running sync transport: push everything still
/// waiting to upload, pull once more so edits made elsewhere aren't
/// stranded, then stop. Data already in that cloud stays there.
final class StopSync extends PlanChangeStep {
  const StopSync(this.kind);

  final SyncKind kind;

  @override
  bool operator ==(Object other) => other is StopSync && other.kind == kind;

  @override
  int get hashCode => kind.hashCode;
}

/// Start a sync transport with a full upload of everything on the phone,
/// merged field by field with whatever the cloud already holds (a returning
/// subscriber gets their website copy back, not overwritten).
final class StartSyncWithFullUpload extends PlanChangeStep {
  const StartSyncWithFullUpload(this.kind);

  final SyncKind kind;

  @override
  bool operator ==(Object other) =>
      other is StartSyncWithFullUpload && other.kind == kind;

  @override
  int get hashCode => kind.hashCode;
}

/// The website vault turns read-only (grace period, then server deletion
/// after warnings). Only the server copy is ever deleted.
final class WebsiteBecomesReadOnly extends PlanChangeStep {
  const WebsiteBecomesReadOnly();

  @override
  bool operator ==(Object other) => other is WebsiteBecomesReadOnly;

  @override
  int get hashCode => (WebsiteBecomesReadOnly).hashCode;
}

/// What happens to data when an account moves between plans.
///
/// Pure and exhaustive: covers every row of the spec's "Plan changes" table
/// for Base, Essential and Pro, for guests and signed-in accounts.
@immutable
final class PlanChange {
  const PlanChange._(this.from, this.to, this.steps);

  /// The steps to move from [from] to [to].
  ///
  /// [isGuest] is true when no one is signed in. A guest never syncs, so a
  /// guest's change has no stop or website steps; moving a guest to a plan
  /// that needs an account starts with sign-in. A guest who already paid
  /// (sign-in failed at purchase) uses [PlanChange.finishAccountSetup].
  factory PlanChange.between(Plan from, Plan to, {required bool isGuest}) {
    if (from == to) return PlanChange._(from, to, const []);
    final fromPolicy = PlanPolicy.of(from);
    final toPolicy = PlanPolicy.of(to);

    if (isGuest) {
      if (!toPolicy.requiresAccount) return PlanChange._(from, to, const []);
      return PlanChange._(from, to, [
        RequireSignIn(toPolicy.signInMethods),
        const OfferMoveGuestItems(),
        if (toPolicy.syncKind != SyncKind.none)
          StartSyncWithFullUpload(toPolicy.syncKind),
      ]);
    }

    final steps = <PlanChangeStep>[
      if (fromPolicy.syncKind != toPolicy.syncKind) ...[
        if (fromPolicy.syncKind != SyncKind.none) StopSync(fromPolicy.syncKind),
        if (toPolicy.syncKind != SyncKind.none)
          StartSyncWithFullUpload(toPolicy.syncKind),
      ],
      if (fromPolicy.hasWebsiteVault && !toPolicy.hasWebsiteVault)
        const WebsiteBecomesReadOnly(),
    ];
    return PlanChange._(from, to, List.unmodifiable(steps));
  }

  /// A guest who already owns [plan] (paid, but sign-in failed) has now
  /// signed in: offer to move the guest items, then start the plan's sync.
  factory PlanChange.finishAccountSetup(Plan plan) {
    final kind = PlanPolicy.of(plan).syncKind;
    return PlanChange._(plan, plan, [
      const OfferMoveGuestItems(),
      if (kind != SyncKind.none) StartSyncWithFullUpload(kind),
    ]);
  }

  final Plan from;
  final Plan to;
  final List<PlanChangeStep> steps;

  bool get isUpgrade => to.index > from.index;

  bool get isDowngrade => to.index < from.index;
}
