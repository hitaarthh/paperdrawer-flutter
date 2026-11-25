import 'package:flutter/foundation.dart';

import '../reminders/notification_kind.dart';
import 'plan.dart';

/// The rules one plan enforces (strategy pattern).
///
/// Code never asks "is this Pro?". It asks the active policy a question
/// ("may I add an item?", "which sync runs?", "is email a channel?"), so a
/// plan's rules live in exactly one class and adding a plan means adding one
/// subclass.
///
/// The hierarchy is sealed: [PlanPolicy.of] is exhaustive, and every policy
/// must answer every question, because each getter below is abstract.
@immutable
sealed class PlanPolicy {
  const PlanPolicy();

  /// The policy for [plan].
  factory PlanPolicy.of(Plan plan) => switch (plan) {
    Plan.base => const BasePolicy(),
    Plan.essential => const EssentialPolicy(),
    Plan.pro => const ProPolicy(),
  };

  Plan get plan;

  /// The most active (not archived) items, or `null` for no limit.
  ItemLimit? get itemLimit;

  /// True when the plan can't be used without a PaperDrawer account.
  bool get requiresAccount;

  /// The sign-in methods offered when this plan asks for an account. Empty
  /// for plans that never ask.
  Set<SignInMethod> get signInMethods;

  /// Where the vault is copied besides this device.
  SyncKind get syncKind;

  /// True when the vault survives deleting the app.
  bool get survivesAppDeletion => syncKind != SyncKind.none;

  /// The website shows the vault (not just marketing and account pages).
  bool get hasWebsiteVault;

  /// Reminders can also be sent by email from the server.
  bool get hasEmailReminders;

  /// Notification kinds this plan offers in Settings › Notifications.
  Set<NotificationKind> get notificationKinds;

  /// The channels a notification of [kind] can use on this plan.
  Set<NotificationChannel> channelsFor(NotificationKind kind) {
    if (!notificationKinds.contains(kind)) return const {};
    final emailable = kind.isDeadline || kind == NotificationKind.weeklySummary;
    return {
      NotificationChannel.push,
      if (hasEmailReminders && emailable) NotificationChannel.email,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is PlanPolicy && other.plan == plan;

  @override
  int get hashCode => plan.hashCode;
}

/// Kinds every plan offers.
const _everyPlanKinds = {
  NotificationKind.returnWindow,
  NotificationKind.warranty,
  NotificationKind.partWarranty,
  NotificationKind.policyRenewal,
  NotificationKind.validity,
  NotificationKind.agreementTerm,
  NotificationKind.weeklySummary,
  NotificationKind.unfinishedItem,
  NotificationKind.tips,
};

/// Free, no account, this device only. Capped at 25 active items, with a
/// warning from 20 (final design: "Base warns from 20 items and stops at 25
/// with a way out").
final class BasePolicy extends PlanPolicy {
  const BasePolicy();

  @override
  Plan get plan => Plan.base;

  @override
  ItemLimit get itemLimit => const ItemLimit(max: 25, warnFrom: 20);

  @override
  bool get requiresAccount => false;

  @override
  Set<SignInMethod> get signInMethods => const {};

  @override
  SyncKind get syncKind => SyncKind.none;

  @override
  bool get hasWebsiteVault => false;

  @override
  bool get hasEmailReminders => false;

  @override
  Set<NotificationKind> get notificationKinds => const {
    ..._everyPlanKinds,
    NotificationKind.backupReminder,
  };
}

/// Paid once. Sign in with Apple; sync through the user's own iCloud.
final class EssentialPolicy extends PlanPolicy {
  const EssentialPolicy();

  @override
  Plan get plan => Plan.essential;

  @override
  ItemLimit? get itemLimit => null;

  @override
  bool get requiresAccount => true;

  /// Email is still open in the spec ("Essential: email + password as well
  /// as Apple?"). Apple only until decided.
  @override
  Set<SignInMethod> get signInMethods => const {SignInMethod.apple};

  @override
  SyncKind get syncKind => SyncKind.iCloud;

  @override
  bool get hasWebsiteVault => false;

  @override
  bool get hasEmailReminders => false;

  @override
  Set<NotificationKind> get notificationKinds => const {
    ..._everyPlanKinds,
    NotificationKind.syncProblem,
  };
}

/// Subscription. Sync through PaperDrawer cloud; website vault; email.
final class ProPolicy extends PlanPolicy {
  const ProPolicy();

  @override
  Plan get plan => Plan.pro;

  @override
  ItemLimit? get itemLimit => null;

  @override
  bool get requiresAccount => true;

  /// Google joins with the Android app.
  @override
  Set<SignInMethod> get signInMethods => const {
    SignInMethod.apple,
    SignInMethod.email,
  };

  @override
  SyncKind get syncKind => SyncKind.paperDrawerCloud;

  @override
  bool get hasWebsiteVault => true;

  @override
  bool get hasEmailReminders => true;

  @override
  Set<NotificationKind> get notificationKinds => const {
    ..._everyPlanKinds,
    NotificationKind.syncProblem,
  };
}

/// A cap on active items.
@immutable
final class ItemLimit {
  const ItemLimit({required this.max, required this.warnFrom})
    : assert(max > 0),
      assert(warnFrom > 0 && warnFrom <= max);

  final int max;

  /// From this count on, the UI shows "n of max" warnings.
  final int warnFrom;

  @override
  bool operator ==(Object other) =>
      other is ItemLimit && other.max == max && other.warnFrom == warnFrom;

  @override
  int get hashCode => Object.hash(max, warnFrom);
}
