import 'package:paperdrawer/core/time/clock.dart';
import 'package:paperdrawer/domain/account/account_scope.dart';
import 'package:paperdrawer/domain/plans/plan_policy.dart';
import 'package:paperdrawer/domain/reminders/item_reminder_setting.dart';
import 'package:paperdrawer/domain/reminders/notification_kind.dart';
import 'package:paperdrawer/domain/reminders/notification_preferences.dart';
import 'package:paperdrawer/domain/reminders/reminder_item.dart';
import 'package:paperdrawer/domain/reminders/reminder_planner.dart';

/// Shared builders for the reminder tests.
///
/// The default "now" is Wed 25 Nov 2026, 08:00 local wall clock.
DateTime day(int y, int m, int d) => DateTime.utc(y, m, d);

FixedClock clockAt(int y, int m, int d, [int hour = 8, int minute = 0]) =>
    FixedClock(DateTime(y, m, d, hour, minute));

const projectKey = 'aHR0cHM6Ly9leGFtcGxlLnN1cGFiYXNlLmNv';
const userId = '6f1d2c3b-4a5e-4f60-8a7b-9c0d1e2f3a4b';

UserScope user() =>
    UserScope.parse(projectKey: projectKey, userId: userId).requireValue;

ReminderDeadline deadline(
  NotificationKind kind,
  DateTime date, {
  bool renews = false,
  bool done = false,
  String partName = '',
  bool keepsNoClaimBonus = false,
}) => ReminderDeadline(
  kind: kind,
  date: date,
  renews: renews,
  done: done,
  partName: partName,
  keepsNoClaimBonus: keepsNoClaimBonus,
);

ReminderItem item(
  String id,
  List<ReminderDeadline> deadlines, {
  String? name,
  ItemReminderSetting setting = ItemReminderSetting.defaults,
  DateTime? savedOn,
  bool isUnfinished = false,
}) => ReminderItem(
  id: id,
  name: name ?? 'Item $id',
  deadlines: deadlines,
  setting: setting,
  savedOn: savedOn,
  isUnfinished: isUnfinished,
);

ReminderPlanInput input(
  List<ReminderItem> items, {
  PlanPolicy policy = const EssentialPolicy(),
  NotificationPreferences? preferences,
  List<ReminderSnooze> snoozes = const [],
  DateTime? lastExportOn,
  DateTime? drawerStartedOn,
  AccountScope scope = const GuestScope(),
  bool forOtherAccount = false,
}) => ReminderPlanInput(
  scope: scope,
  policy: policy,
  preferences: preferences ?? NotificationPreferences.defaults(),
  items: items,
  snoozes: snoozes,
  lastExportOn: lastExportOn,
  drawerStartedOn: drawerStartedOn,
  forOtherAccount: forOtherAccount,
);

/// Preferences where [kind] reminds only at [leadDays].
NotificationPreferences withLeads(
  NotificationKind kind,
  List<int> leadDays, [
  NotificationPreferences? base,
]) => (base ?? NotificationPreferences.defaults())
    .withKind(kind, on: true, leadDays: leadDays)
    .requireValue;

/// Preferences with every kind except [keep] switched off.
NotificationPreferences only(Set<NotificationKind> keep) {
  var prefs = NotificationPreferences.defaults();
  for (final kind in NotificationKind.values) {
    if (!keep.contains(kind)) {
      prefs = prefs.withKind(kind, on: false).requireValue;
    }
  }
  return prefs;
}
