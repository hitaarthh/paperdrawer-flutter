import 'package:flutter/foundation.dart';

import '../../core/time/clock.dart';
import '../account/account_scope.dart';
import 'notification_payload.dart';
import 'reminder_item.dart';

/// The long-press actions on a notification (iOSNotifActions).
enum NotificationAction {
  markDone('pd.mark_done', opensApp: false),
  remindTomorrow('pd.remind_tomorrow', opensApp: false),
  openItem('pd.open_item', opensApp: true),
  muteItem('pd.mute_item', opensApp: false);

  const NotificationAction(this.identifier, {required this.opensApp});

  /// The platform action identifier (stable; registered with iOS).
  final String identifier;

  /// Whether iOS should bring the app to the foreground for it.
  final bool opensApp;

  static NotificationAction? byIdentifier(String identifier) {
    for (final action in values) {
      if (action.identifier == identifier) return action;
    }
    return null;
  }
}

/// The iOS notification category, which decides the long-press actions.
enum NotificationCategory {
  /// Deadline reminders: Mark as done, Remind me tomorrow, Open item, Mute
  /// this item.
  deadline('pd.deadline', [
    NotificationAction.markDone,
    NotificationAction.remindTomorrow,
    NotificationAction.openItem,
    NotificationAction.muteItem,
  ]),

  /// About one item but not one deadline (unfinished item, one-off
  /// reminder): Open item, Mute this item.
  item('pd.item', [NotificationAction.openItem, NotificationAction.muteItem]),

  /// Weekly summary, backup, sync problems, tips: a tap opens the route.
  general('pd.general', []);

  const NotificationCategory(this.identifier, this.actions);

  final String identifier;
  final List<NotificationAction> actions;
}

/// What the app should do after a tap or an action on a notification.
///
/// The data layer carries it out (writes go through repositories); this
/// type only decides.
@immutable
sealed class ReminderCommand {
  const ReminderCommand();
}

/// Navigate to [route] in the open drawer.
final class OpenRoute extends ReminderCommand {
  const OpenRoute(this.route);

  final String route;

  @override
  bool operator ==(Object other) => other is OpenRoute && other.route == route;

  @override
  int get hashCode => route.hashCode;
}

/// Store [mark] on item [itemId]: that window's reminders stop.
final class MarkDeadlineDone extends ReminderCommand {
  const MarkDeadlineDone(this.itemId, this.mark);

  final String itemId;
  final DeadlineMark mark;

  @override
  bool operator ==(Object other) =>
      other is MarkDeadlineDone && other.itemId == itemId && other.mark == mark;

  @override
  int get hashCode => Object.hash(itemId, mark);
}

/// Store [snooze] and reschedule.
final class SnoozeDeadline extends ReminderCommand {
  const SnoozeDeadline(this.snooze);

  final ReminderSnooze snooze;

  @override
  bool operator ==(Object other) =>
      other is SnoozeDeadline && other.snooze == snooze;

  @override
  int get hashCode => snooze.hashCode;
}

/// Set item [itemId]'s reminders to `ItemReminderSetting.muted`.
final class MuteItem extends ReminderCommand {
  const MuteItem(this.itemId);

  final String itemId;

  @override
  bool operator ==(Object other) => other is MuteItem && other.itemId == itemId;

  @override
  int get hashCode => itemId.hashCode;
}

/// Why a notification response is ignored.
enum IgnoreReason {
  /// Not a payload PaperDrawer wrote.
  unreadable,

  /// It belongs to another account on this phone; it must not touch the
  /// open drawer.
  otherAccount,

  /// An action identifier this version doesn't know.
  unknownAction,

  /// The action needs an item or deadline the payload doesn't carry
  /// (for example a design-v1 payload).
  missingTarget,
}

/// Do nothing.
final class IgnoreNotification extends ReminderCommand {
  const IgnoreNotification(this.reason);

  final IgnoreReason reason;

  @override
  bool operator ==(Object other) =>
      other is IgnoreNotification && other.reason == reason;

  @override
  int get hashCode => reason.hashCode;
}

/// Turns a notification response (tap or action) into a [ReminderCommand].
final class NotificationActionResolver {
  const NotificationActionResolver(this._clock);

  final Clock _clock;

  /// [actionId] is `null` for a plain tap. [active] is the open drawer.
  ReminderCommand resolve({
    required String? payload,
    required String? actionId,
    required AccountScope active,
  }) {
    final parsed = NotificationPayload.parse(payload);
    if (parsed == null) {
      return const IgnoreNotification(IgnoreReason.unreadable);
    }
    if (parsed.scope != active) {
      return const IgnoreNotification(IgnoreReason.otherAccount);
    }
    if (actionId == null) return OpenRoute(parsed.route);
    final action = NotificationAction.byIdentifier(actionId);
    if (action == null) {
      return const IgnoreNotification(IgnoreReason.unknownAction);
    }
    final itemId = parsed.itemId;
    final kind = parsed.kind;
    final deadline = parsed.deadline;
    const missing = IgnoreNotification(IgnoreReason.missingTarget);
    return switch (action) {
      NotificationAction.openItem => OpenRoute(parsed.route),
      NotificationAction.muteItem => itemId == null ? missing : MuteItem(itemId),
      NotificationAction.markDone =>
        itemId == null || kind == null || deadline == null || !kind.isDeadline
            ? missing
            : MarkDeadlineDone(itemId, DeadlineMark(kind, deadline)),
      NotificationAction.remindTomorrow =>
        itemId == null || kind == null || deadline == null || !kind.isDeadline
            ? missing
            : SnoozeDeadline(
                ReminderSnooze.tomorrow(
                  itemId: itemId,
                  kind: kind,
                  deadline: deadline,
                  today: _clock.today(),
                ),
              ),
    };
  }
}
