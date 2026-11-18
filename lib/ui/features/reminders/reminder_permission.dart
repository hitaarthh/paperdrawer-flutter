import '../../../data/repositories/settings_repository.dart';
import '../../../data/services/reminder_scheduler.dart';
import '../../../domain/item_status.dart';
import '../../../domain/models/item.dart';

/// The one path that switches reminders on, shared by Settings and the
/// "Turn on reminders" offer: ask iOS for permission, then save the choice.
///
/// Returns whether notifications were allowed. Either answer settles the
/// offer, because iOS shows its prompt only once. Without a scheduler (no
/// notification plugin) nothing is asked and nothing is saved.
Future<bool> turnOnReminders(
  ReminderScheduler? scheduler,
  SettingsRepository settings,
) async {
  if (scheduler == null) return false;
  final granted = await scheduler.requestPermission();
  if (granted) await settings.setRemindersOn(true);
  await settings.markRemindersOffered();
  return granted;
}

/// Whether to offer reminders right after [saved] was added: only while the
/// offer is unanswered, reminders are off, and the new item has a window that
/// a reminder could actually be about.
bool shouldOfferReminders({
  required ReminderScheduler? scheduler,
  required SettingsRepository settings,
  required Item saved,
  required DateTime today,
}) =>
    scheduler != null &&
    !settings.remindersOn &&
    !settings.remindersOffered &&
    saved.draft.remind &&
    !saved.isArchived &&
    windowsOf(saved).any((window) => !window.isEnded(today));
