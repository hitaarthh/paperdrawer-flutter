import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/item_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../data/services/reminder_scheduler.dart';
import '../../../data/services/today.dart';
import '../../../routing/router.dart';
import '../../core/theme/type.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/list_row.dart';
import '../../core/widgets/nav.dart';
import '../account/shared_session.dart';

class DrawerNotificationButton extends StatelessWidget {
  const DrawerNotificationButton({this.fromDrawer = false, super.key});

  final bool fromDrawer;

  @override
  Widget build(BuildContext context) => PdGlassIcon(
    key: const ValueKey('drawer-notifications'),
    label: 'Notifications',
    icon: const Icon(LucideIcons.bell),
    onPressed: () => context.push(Routes.notifications, extra: fromDrawer),
  );
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
    final List<PlannedReminder> reminders;
    final String emptyTitle;
    final String emptyBody;
    if (shared) {
      final emailReminders = context
          .watch<SharedSession>()
          .vault
          ?.profile
          ?.emailReminders;
      reminders = const [];
      emptyTitle = 'No device notifications';
      emptyBody = emailReminders == true
          ? 'Reminders for this account arrive by email.'
          : 'Manage email reminders for this account in Settings.';
    } else {
      final settings = context.watch<SettingsRepository>();
      reminders = settings.remindersOn
          ? planReminders(
              items: context.watch<ItemRepository>().active,
              leadDays: settings.leadDays,
              now: context.watch<Today>().instant,
            )
          : const [];
      emptyTitle = settings.remindersOn
          ? 'No upcoming notifications'
          : 'Notifications are off';
      emptyBody = settings.remindersOn
          ? 'Set a reminder on a file to see it here.'
          : 'Turn them on in Settings to get reminders on this iPhone.';
    }
    return PdPushedScaffold(
      title: 'Notifications',
      backLabel: fromDrawer ? 'Drawer' : 'Home',
      glassBack: true,
      onBack: () => context.canPop()
          ? context.pop()
          : context.go(fromDrawer ? Routes.vault : Routes.home),
      children: [
        if (reminders.isEmpty)
          DashedTile(title: emptyTitle, body: emptyBody)
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
      ],
    );
  }
}
