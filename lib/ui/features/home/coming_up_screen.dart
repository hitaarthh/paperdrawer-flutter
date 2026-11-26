import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/item_repository.dart';
import '../../../data/services/today.dart';
import '../../../domain/formats.dart';
import '../../../routing/router.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/type.dart';
import '../../core/widgets/brand_bar.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/vault_ticket.dart';
import '../reminders/reminder_inbox.dart';
import '../shell/tab_reselect.dart';
import 'home_view_data.dart';

class ComingUpScreen extends StatefulWidget {
  const ComingUpScreen({super.key});

  @override
  State<ComingUpScreen> createState() => _ComingUpScreenState();
}

class _ComingUpScreenState extends State<ComingUpScreen> {
  final _scroll = ScrollController();
  late final _reselect = context.read<TabReselect>();

  @override
  void initState() {
    super.initState();
    _reselect.addListener(_resetHome);
  }

  @override
  void dispose() {
    _reselect.removeListener(_resetHome);
    _scroll.dispose();
    super.dispose();
  }

  void _resetHome() {
    if (_reselect.index != 0 || !_scroll.hasClients) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _scroll.jumpTo(0);
    } else {
      _scroll.animateTo(
        0,
        duration: Pd.sheetDuration,
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final clock = context.watch<Today>();
    final today = clock.value;
    final data = HomeViewData(
      items: context.watch<ItemRepository>().active,
      today: today,
      now: clock.instant,
    );
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: Pd.bg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Pd.maxContent),
          child: Column(
            children: [
              PdBrandBar(
                onMarkTap: () => context.go(Routes.vault),
                trailing: const DrawerNotificationButton(),
              ),
              Expanded(
                child: ListView(
                  key: const ValueKey('coming-up-list'),
                  controller: _scroll,
                  padding: EdgeInsets.fromLTRB(
                    Pd.margin,
                    Pd.s3,
                    Pd.margin,
                    bottom + Pd.s8,
                  ),
                  children: [
                    Text(
                      _weekdayDate(today),
                      style: PdType.label.copyWith(color: Pd.textMuted),
                    ),
                    const SizedBox(height: Pd.s2),
                    Semantics(
                      header: true,
                      child: Text('Coming up', style: PdType.heroTitle),
                    ),
                    const SizedBox(height: Pd.s6),
                    if (data.tickets.isEmpty)
                      const DashedTile(
                        title: 'Nothing coming up',
                        body: 'Warranty dates, policy dates and reminders appear here.',
                      ),
                    for (final ticket in data.tickets)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Pd.s3),
                        child: VaultTicket(
                          key: ValueKey('home-ticket-${ticket.key}'),
                          number: ticket.number,
                          unit: ticket.unit,
                          kicker: ticket.kicker,
                          title: ticket.title,
                          body: ticket.body,
                          tone: ticket.tone,
                          semanticLabel: ticket.semanticLabel,
                          onTap: () =>
                              context.push(Routes.homeItem(ticket.itemId)),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _weekdayDate(DateTime date) {
  const weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  return '${weekdays[date.weekday - 1]} ${shortDate(date).toUpperCase()}';
}
