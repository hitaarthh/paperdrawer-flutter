import '../item_status.dart';
import 'notification_kind.dart';
import 'reminder_item.dart';

/// Which notification kind reminds about a cover window, and back.
///
/// The two catalogues name the same six deadlines differently
/// (`WindowType` is design-v1's meter vocabulary). This is the only place
/// that maps them; both switches are exhaustive.
extension WindowTypeKind on WindowType {
  NotificationKind get notificationKind => switch (this) {
    WindowType.returnWindow => NotificationKind.returnWindow,
    WindowType.warranty => NotificationKind.warranty,
    WindowType.componentWarranty => NotificationKind.partWarranty,
    WindowType.policyYear => NotificationKind.policyRenewal,
    WindowType.validity => NotificationKind.validity,
    WindowType.term => NotificationKind.agreementTerm,
  };
}

extension NotificationKindWindow on NotificationKind {
  /// The window type a deadline kind reminds about; `null` for kinds that
  /// are not about a deadline.
  WindowType? get windowType => switch (this) {
    NotificationKind.returnWindow => WindowType.returnWindow,
    NotificationKind.warranty => WindowType.warranty,
    NotificationKind.partWarranty => WindowType.componentWarranty,
    NotificationKind.policyRenewal => WindowType.policyYear,
    NotificationKind.validity => WindowType.validity,
    NotificationKind.agreementTerm => WindowType.term,
    NotificationKind.weeklySummary => null,
    NotificationKind.unfinishedItem => null,
    NotificationKind.backupReminder => null,
    NotificationKind.syncProblem => null,
    NotificationKind.tips => null,
  };
}

/// Builds the planner's deadline from a design-v1 [CoverWindow].
///
/// [done] is true when the user marked this window done for this end date
/// (see `DeadlineMark`). [keepsNoClaimBonus] is for health and motor
/// policies, whose renewal copy mentions the no-claim bonus.
ReminderDeadline deadlineFromWindow(
  CoverWindow window, {
  bool done = false,
  bool keepsNoClaimBonus = false,
}) => ReminderDeadline(
  kind: window.type.notificationKind,
  date: window.end,
  renews: window.renews,
  partName: window.component,
  done: done,
  keepsNoClaimBonus: keepsNoClaimBonus,
);
