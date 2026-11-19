import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/item_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../data/repositories/shared_inbox_repository.dart';
import '../../../data/services/reminder_scheduler.dart';
import '../../../data/services/today.dart';
import '../../../routing/router.dart';
import '../../core/theme/type.dart';
import '../../core/widgets/button.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/list_row.dart';
import '../../core/widgets/nav.dart';
import '../../core/widgets/snackbar.dart';

class DrawerNotificationButton extends StatelessWidget {
  const DrawerNotificationButton({this.fromDrawer = false, super.key});

  final bool fromDrawer;

  @override
  Widget build(BuildContext context) {
    final unread = context.watch<SharedInboxRepository?>()?.unread ?? 0;
    return PdGlassIcon(
      key: const ValueKey('drawer-notifications'),
      label: unread == 0 ? 'Notifications' : 'Notifications, $unread unread',
      icon: Icon(unread == 0 ? LucideIcons.bell : LucideIcons.bellDot),
      systemIcon: unread == 0 ? 'bell' : 'bell.badge',
      onPressed: () => context.push(Routes.notifications, extra: fromDrawer),
    );
  }
}

class ReminderInbox extends StatelessWidget {
  const ReminderInbox({
    this.fromDrawer = false,
    this.shared = false,
    super.key,
  });

  final bool fromDrawer;
  final bool shared;

  @override
  Widget build(BuildContext context) {
    return PdPushedScaffold(
      title: 'Notifications',
      backLabel: fromDrawer ? 'Drawer' : 'Home',
      glassBack: true,
      onBack: () => context.canPop()
          ? context.pop()
          : context.go(fromDrawer ? Routes.vault : Routes.home),
      children: shared
          ? _sharedNotifications(context)
          : _localReminders(context),
    );
  }

  List<Widget> _localReminders(BuildContext context) {
    final settings = context.watch<SettingsRepository>();
    final reminders = settings.remindersOn
        ? planReminders(
            items: context.watch<ItemRepository>().active,
            leadDays: settings.leadDays,
            now: context.watch<Today>().instant,
          )
        : const [];
    return [
      if (reminders.isEmpty)
        DashedTile(
          title: settings.remindersOn
              ? 'No upcoming notifications'
              : 'Notifications are off',
          body: settings.remindersOn
              ? 'Set a reminder on a file to see it here.'
              : 'Turn them on in Settings to get reminders on this iPhone.',
        )
      else ...[
        Text('Upcoming', style: PdType.title2),
        PdListGroup(
          children: [
            for (final reminder in reminders)
              PdListRow(
                title: reminder.title,
                value: DateFormat('EEE, d MMM · h:mm a').format(reminder.at),
                chevron: true,
                onTap: () => context.push(reminder.location),
              ),
          ],
        ),
      ],
    ];
  }

  List<Widget> _sharedNotifications(BuildContext context) {
    final inbox = context.watch<SharedInboxRepository?>();
    if (inbox == null) return const [];
    return [
      if (inbox.failed)
        DashedTile(
          title: 'Couldn’t refresh reminders',
          body: 'Check your connection and try again.',
          action: PdButton.text(label: 'Try again', onPressed: inbox.refresh),
        )
      else if (!inbox.loaded)
        Text('Loading reminders…', style: PdType.callout)
      else if (inbox.items.isEmpty)
        const DashedTile(
          title: 'You’re caught up',
          body: 'Due reminders will appear here.',
        ),
      if (inbox.items.isNotEmpty)
        PdListGroup(
          children: [
            for (final notification in inbox.items)
              PdListRow(
                key: ValueKey('notification-${notification.id}'),
                title: notification.itemName,
                value:
                    '${notification.label} · '
                    '${DateFormat('d MMM yyyy').format(notification.deadline)}',
                tag: notification.isRead ? null : 'Unread',
                chevron: true,
                onTap: () async {
                  try {
                    if (!await inbox.open(notification) || !context.mounted) {
                      return;
                    }
                    context.push(Routes.item(notification.itemId));
                  } catch (_) {
                    if (!context.mounted) return;
                    showPdSnackbar(
                      context,
                      'Couldn’t open this reminder. Try again.',
                    );
                  }
                },
              ),
          ],
        ),
    ];
  }
}
