import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:material_ui/material_ui.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/type.dart';
import '../../core/widgets/brand_bar.dart';
import '../../core/widgets/filter_tabs.dart';
import '../../core/widgets/paper.dart';
import '../../core/widgets/stamp.dart';
import '../../core/widgets/vault_ticket.dart';
import 'claims_list_data.dart';

/// The same Claims tab layout for device-only and shared claims.
class ClaimsOverview extends StatefulWidget {
  const ClaimsOverview({
    required this.data,
    required this.onVault,
    required this.onOpen,
    required this.empty,
    this.notice,
    this.controller,
    this.onRefresh,
    this.rowKeyPrefix = 'claim-row',
    super.key,
  });

  final ClaimsListData? data;
  final VoidCallback onVault;
  final ValueChanged<String> onOpen;
  final Widget Function(ClaimsFilter) empty;
  final Widget? notice;
  final ScrollController? controller;
  final Future<void> Function()? onRefresh;
  final String rowKeyPrefix;

  @override
  State<ClaimsOverview> createState() => _ClaimsOverviewState();
}

class _ClaimsOverviewState extends State<ClaimsOverview> {
  var _filter = ClaimsFilter.open;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final visible = data?.visible(_filter);
    final featured = data?.featured;
    final scroll = CustomScrollView(
      key: const ValueKey('claims-scroll'),
      controller: widget.controller,
      physics: widget.onRefresh == null
          ? null
          : const AlwaysScrollableScrollPhysics(),
      slivers: [
        _inset(
          Semantics(
            header: true,
            child: Text('Claims', style: PdType.heroTitle),
          ),
          top: Pd.s3,
        ),
        if (widget.notice case final notice?) _inset(notice, top: Pd.s6),
        if (featured != null)
          _inset(
            VaultTicket(
              key: ValueKey('claim-featured-${featured.id}'),
              number: featured.waitDays.toString().padLeft(2, '0'),
              unit: featured.waitDays == 1 ? 'DAY' : 'DAYS',
              kicker: featured.ticketKicker,
              title: featured.title,
              body: featured.ticketBody,
              tone: VaultTicketTone.lime,
              semanticLabel:
                  '${featured.title}. ${featured.ticketKicker}. ${featured.ticketBody}',
              onTap: () => widget.onOpen(featured.id),
            ),
            top: Pd.s6,
          ),
        if (data != null && visible != null) ...[
          SliverPadding(
            padding: const EdgeInsets.only(top: Pd.s6),
            sliver: SliverToBoxAdapter(
              child: PdFilterTabs(
                children: [
                  for (final filter in ClaimsFilter.values)
                    PdFilterTab(
                      key: ValueKey('claim-${filter.name}-filter'),
                      label: filter.name.toUpperCase(),
                      count: data.count(filter),
                      selected: _filter == filter,
                      onTap: () => setState(() => _filter = filter),
                    ),
                ],
              ),
            ),
          ),
          if (visible.isEmpty)
            _inset(widget.empty(_filter), top: Pd.s6)
          else ...[
            _inset(
              Text(
                _filter == ClaimsFilter.settled || data.openCount == 0
                    ? 'MOST RECENTLY SETTLED'
                    : 'NEEDS YOU FIRST · OLDEST REPLY FIRST',
                style: PdType.label.copyWith(color: Pd.textMuted),
              ),
              top: Pd.s3,
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                Pd.margin,
                Pd.s6,
                Pd.margin,
                0,
              ),
              sliver: SliverList.builder(
                itemCount: visible.length,
                itemBuilder: (context, index) {
                  final claim = visible[index];
                  return Padding(
                    padding: EdgeInsets.only(top: index == 0 ? 0 : Pd.s3),
                    child: _ClaimRow(
                      key: ValueKey('${widget.rowKeyPrefix}-${claim.id}'),
                      claim: claim,
                      onTap: () => widget.onOpen(claim.id),
                    ),
                  );
                },
              ),
            ),
          ],
          _inset(
            Text(
              'PAPER DRAWER GUIDES YOU THROUGH EACH STEP. '
              'YOU CHOOSE WHEN TO CONTACT SOMEONE. FOR GENERAL GUIDANCE ONLY.',
              style: PdType.tabLabel.copyWith(color: Pd.textMuted, height: 1.6),
            ),
            top: Pd.s6,
          ),
        ],
        SliverToBoxAdapter(
          child: SizedBox(
            height: Pd.s12 + MediaQuery.paddingOf(context).bottom,
          ),
        ),
      ],
    );
    final refresh = widget.onRefresh;
    return Scaffold(
      backgroundColor: Pd.bg,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Pd.maxContent),
            child: Column(
              children: [
                PdBrandBar(onMarkTap: widget.onVault),
                Expanded(
                  child: refresh == null
                      ? scroll
                      : Semantics(
                          container: true,
                          customSemanticsActions: {
                            const CustomSemanticsAction(
                              label: 'Refresh from Paper Drawer web',
                            ): refresh,
                          },
                          child: RefreshIndicator.adaptive(
                            onRefresh: refresh,
                            child: scroll,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _inset(Widget child, {required double top}) => SliverPadding(
    padding: EdgeInsets.fromLTRB(Pd.margin, top, Pd.margin, 0),
    sliver: SliverToBoxAdapter(child: child),
  );
}

class _ClaimRow extends StatelessWidget {
  const _ClaimRow({required this.claim, required this.onTap, super.key});

  final ClaimListEntry claim;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(Pd.rSm));
    const dayWidth = Pd.s12 + Pd.s4;
    return Semantics(
      button: true,
      excludeSemantics: true,
      label:
          '${claim.title}. Day ${claim.day}. ${claim.status.label}. '
          '${claim.metadata}. ${claim.step}. ${claim.next}.',
      onTap: onTap,
      child: Material(
        color: Pd.surface2,
        shape: const RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: Pd.hairline),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.all(Pd.s4),
            child: Stack(
              children: [
                PositionedDirectional(
                  start: dayWidth,
                  top: 0,
                  bottom: 0,
                  child: RotatedBox(
                    quarterTurns: 1,
                    child: DashedRule(
                      color: Pd.text.withValues(alpha: 0.12),
                      thickness: 2,
                    ),
                  ),
                ),
                Row(
                  children: [
                    SizedBox(
                      width: dayWidth,
                      child: Padding(
                        padding: const EdgeInsets.only(right: Pd.s3),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'DAY',
                              style: PdType.tabLabel.copyWith(
                                color: Pd.textMuted,
                              ),
                            ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                claim.day.toString().padLeft(2, '0'),
                                style: PdType.claimDay.copyWith(
                                  color: claim.status.needsAction
                                      ? Pd.signal
                                      : Pd.text,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: Pd.s4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: Pd.s1,
                        children: [
                          Text(
                            claim.metadata,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: PdType.tabLabel.copyWith(
                              color: Pd.textMuted,
                            ),
                          ),
                          Text(claim.title, style: PdType.cardTitle),
                          Text(
                            claim.step,
                            style: PdType.tabLabel.copyWith(color: Pd.text2),
                          ),
                          Text(
                            claim.next,
                            style: PdType.footnote.copyWith(
                              color: Pd.textMuted,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: Pd.s1),
                            child: PdStamp(
                              claim.status.stamp,
                              compactLabel: claim.status.label,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
