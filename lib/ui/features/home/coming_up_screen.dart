import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/claim_repository.dart';
import '../../../data/repositories/item_repository.dart';
import '../../../data/services/today.dart';
import '../../../domain/formats.dart';
import '../../../domain/models/claim.dart';
import '../../../routing/router.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/type.dart';
import '../../core/widgets/brand_bar.dart';
import '../../core/widgets/button.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/nav.dart';
import '../../core/widgets/vault_ticket.dart';
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
    final today = context.watch<Today>().value;
    final claims = context.watch<ClaimRepository>().claims;
    final data = HomeViewData(
      items: context.watch<ItemRepository>().active,
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
              PdBrandBar(onMarkTap: () => context.go(Routes.vault)),
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
                      '${_weekdayDate(today)} · ${data.dueCount} DUE SOON · '
                      '${data.openClaims.length} OPEN ${data.openClaims.length == 1 ? 'CLAIM' : 'CLAIMS'}',
                      style: PdType.label.copyWith(color: Pd.textMuted),
                    ),
                    const SizedBox(height: Pd.s2),
                    Semantics(
                      header: true,
                      child: Text('Coming up', style: PdType.heroTitle),
                    ),
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
                              context.push(Routes.item(ticket.itemId!)),
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
                    const SizedBox(height: Pd.s6),
                    _SectionLabel(
                      'Open claims · Your ledgers',
                      count: data.openClaims.length,
                    ),
                    const SizedBox(height: Pd.s3),
                    if (data.openClaims.isEmpty)
                      const DashedTile(
                        title: 'No open claims',
                        body:
                            'You can open a claim from an item in your vault.',
                      ),
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
  const ClaimHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final claims = context.watch<ClaimRepository>().claims;
    final today = context.watch<Today>().value;
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

  final Claim claim;
  final DateTime today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final entry = claim.ledger.firstOrNull;
    final followUp = claim.followUp?.toLocal();
    final status = claim.settledOn != null
        ? 'SETTLED ${_weekdayDate(claim.settledOn!)}'
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
                  '${claim.type.caps} · ${claim.events.length} ${claim.events.length == 1 ? 'ENTRY' : 'ENTRIES'}',
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
