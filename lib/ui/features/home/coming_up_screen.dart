import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/claim_repository.dart';
import '../../../data/repositories/item_repository.dart';
import '../../../data/services/today.dart';
import '../../../domain/formats.dart';
import '../../../routing/router.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/type.dart';
import '../../core/widgets/brand_bar.dart';
import '../../core/widgets/button.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/nav.dart';
import '../../core/widgets/vault_ticket.dart';
import '../account/shared_session.dart';
import '../reminders/reminder_inbox.dart';
import '../shell/tab_reselect.dart';
import 'home_view_data.dart';

class ComingUpScreen extends StatefulWidget {
  const ComingUpScreen({this.shared = false, super.key});

  final bool shared;

  @override
  State<ComingUpScreen> createState() => _ComingUpScreenState();
}

class _ComingUpScreenState extends State<ComingUpScreen> {
  final _scroll = ScrollController();
  late final _reselect = widget.shared ? null : context.read<TabReselect>();

  @override
  void initState() {
    super.initState();
    _reselect?.addListener(_resetHome);
  }

  @override
  void dispose() {
    _reselect?.removeListener(_resetHome);
    _scroll.dispose();
    super.dispose();
  }

  void _resetHome() {
    if (_reselect?.index != 0 || !_scroll.hasClients) return;
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
    final session = widget.shared ? context.watch<SharedSession>() : null;
    final vault = session?.vault;
    final today = (session?.today ?? context.watch<Today>()).value;
    final claims = widget.shared
        ? vault?.claims.map(HomeClaimData.shared).toList() ??
              const <HomeClaimData>[]
        : context
              .watch<ClaimRepository>()
              .claims
              .map(HomeClaimData.local)
              .toList();
    final data = HomeViewData(
      items: widget.shared
          ? vault?.items.map((entry) => entry.item).toList() ?? const []
          : context.watch<ItemRepository>().active,
      claims: claims,
      today: today,
    );
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: Pd.bg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Pd.maxContent),
          child: Column(
            children: [
              PdBrandBar(onMarkTap: () => context.go(Routes.vault), trailing: const DrawerNotificationButton()),
              Expanded(
                child: ListView(
                  key: const ValueKey('coming-up-list'),
                  controller: _scroll,
                  physics: session == null
                      ? null
                      : const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    Pd.margin,
                    Pd.s3,
                    Pd.margin,
                    bottom + Pd.s8,
                  ),
                  children: [
                    Text(
                      '${_weekdayDate(today)} · ${data.dueCount} DUE SOON',
                      style: PdType.label.copyWith(color: Pd.textMuted),
                    ),
                    const SizedBox(height: Pd.s2),
                    Semantics(
                      header: true,
                      child: Text('Coming up', style: PdType.heroTitle),
                    ),
                    if (session?.failed == true) ...[
                      const SizedBox(height: Pd.s6),
                      DashedTile(
                        title: 'Couldn’t refresh Paper Drawer',
                        body: 'Check your connection and try again.',
                        action: PdButton.text(
                          label: 'Try again',
                          onPressed: session!.refresh,
                        ),
                      ),
                    ],
                    if (session?.loading == true && vault == null) ...[
                      const SizedBox(height: Pd.s6),
                      Text('Loading your drawer…', style: PdType.callout),
                    ],
                    if (!widget.shared || vault != null) ...[
                      const SizedBox(height: Pd.s6),
                      const _SectionLabel('Due soon'),
                      const SizedBox(height: Pd.s3),
                      if (data.dueCount == 0)
                        const DashedTile(
                          title: 'Nothing is due soon',
                          body: 'Return windows, warranties and renewals appear here as their dates get closer.',
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
                                context.push(Routes.homeItem(ticket.itemId!)),
                          ),
                        ),
                      if (data.dueCount > 2)
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: PdButton.text(
                            key: const ValueKey('home-more-due'),
                            label: '+${data.dueCount - 2} more due soon',
                            monospaced: true,
                            icon: const Icon(
                              LucideIcons.arrowRight,
                              size: Pd.iconSm,
                            ),
                            onPressed: () =>
                                context.go('${Routes.vault}?filter=due'),
                          ),
                        ),
                      if (data.openClaims.isNotEmpty) ...[
                        const SizedBox(height: Pd.s6),
                        _SectionLabel('Open claims', count: data.openClaims.length),
                        const SizedBox(height: Pd.s3),
                      ],
                      for (final claim in data.openClaims)
                        Padding(
                          padding: const EdgeInsets.only(bottom: Pd.s3),
                          child: _LedgerCard(
                            claim: claim,
                            today: today,
                            onTap: () => context.push(Routes.claim(claim.id)),
                          ),
                        ),
                      if (claims.any((claim) => !claim.isOpen))
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: PdButton.text(
                            key: const ValueKey('home-claim-history'),
                            label: 'Claim history',
                            onPressed: () => context.push(Routes.claims),
                          ),
                        ),
                    ],
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

class ClaimHistoryScreen extends StatelessWidget {
  const ClaimHistoryScreen({this.shared = false, super.key});

  final bool shared;

  @override
  Widget build(BuildContext context) {
    final session = shared ? context.watch<SharedSession>() : null;
    final claims = shared
        ? session?.vault?.claims.map(HomeClaimData.shared).toList() ??
              const <HomeClaimData>[]
        : context
              .watch<ClaimRepository>()
              .claims
              .map(HomeClaimData.local)
              .toList();
    final today = (session?.today ?? context.watch<Today>()).value;
    return PdPushedScaffold(
      title: 'Claim history',
      backLabel: 'Home',
      onBack: () => context.canPop() ? context.pop() : context.go(Routes.home),
      children: [
        if (claims.isEmpty)
          const DashedTile(
            title: 'No claims yet',
            body: 'Open a claim from an item in your vault.',
          ),
        for (final claim in claims)
          Padding(
            padding: const EdgeInsets.only(bottom: Pd.s3),
            child: _LedgerCard(
              claim: claim,
              today: today,
              onTap: () => context.push(Routes.claim(claim.id)),
            ),
          ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label, {this.count});

  final String label;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final style = PdType.label.copyWith(color: Pd.textMuted);
    return Row(
      spacing: Pd.s2,
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(label.toUpperCase(), style: style),
          ),
        ),
        if (count case final count?) Text('$count', style: style),
      ],
    );
  }
}

class _LedgerCard extends StatelessWidget {
  const _LedgerCard({
    required this.claim,
    required this.today,
    required this.onTap,
  });

  final HomeClaimData claim;
  final DateTime today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final entry = claim.entries.firstOrNull;
    final followUp = claim.followUp?.toLocal();
    final settled = claim.settled;
    final status = !claim.isOpen
        ? settled == null
              ? 'SETTLED'
              : 'SETTLED ${_weekdayDate(settled)}'
        : followUp == null
        ? 'NO FOLLOW-UP SET'
        : 'FOLLOW UP ${_weekdayDate(followUp)}';
    return Semantics(
      button: true,
      child: Material(
        color: Pd.surface1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Pd.rSm),
          side: const BorderSide(color: Pd.hairline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('home-claim-${claim.id}'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(Pd.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: Pd.s1,
              children: [
                _SectionLabel(
                  '${claim.category} · ${claim.entries.length} ${claim.entries.length == 1 ? 'ENTRY' : 'ENTRIES'}',
                ),
                Text(claim.title, style: PdType.cardTitle),
                Text(
                  entry == null
                      ? 'No entries yet'
                      : 'Last: ${entry.details.isEmpty ? entry.text : entry.details}, ${shortDate(entry.date)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: PdType.footnote.copyWith(color: Pd.textMuted),
                ),
                Text(
                  status,
                  style: PdType.label.copyWith(
                    color: !claim.isOpen
                        ? Pd.settled
                        : followUp == null
                        ? Pd.textMuted
                        : civil(followUp).isAfter(today)
                        ? Pd.lime
                        : Pd.signal,
                  ),
                ),
              ],
            ),
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
