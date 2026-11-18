import 'dart:math' as math;

import 'package:cupertino_ui/cupertino_ui.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/type.dart';
import '../../core/widgets/vault_ticket.dart';
import 'vault_tickets.dart';

/// "DUE NEXT · 1 OF 3": the soonest deadlines and stalled claims as tickets
/// that scroll sideways, bleeding to the screen edges.
class VaultDueNext extends StatefulWidget {
  const VaultDueNext({
    required this.tickets,
    required this.onOpen,
    required this.onHide,
    super.key,
  });

  final List<VaultTicketData> tickets;
  final ValueChanged<VaultTicketData> onOpen;

  /// Hide a ticket for today (long press, or VoiceOver's dismiss action).
  final ValueChanged<VaultTicketData> onHide;

  @override
  State<VaultDueNext> createState() => _VaultDueNextState();
}

class _VaultDueNextState extends State<VaultDueNext> {
  final _scroll = ScrollController();
  double _stride = 1;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_track);
  }

  @override
  void didUpdateWidget(VaultDueNext oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_index >= widget.tickets.length) _index = 0;
  }

  void _track() {
    final position = _scroll.position;
    final last = widget.tickets.length - 1;
    final index = position.pixels >= position.maxScrollExtent - 1
        ? last
        : (position.pixels / _stride).round().clamp(0, last);
    if (index != _index) setState(() => _index = index);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_track)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tickets = widget.tickets;
    final many = tickets.length > 1;
    return Semantics(
      container: true,
      label: 'Due next',
      explicitChildNodes: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Pd.s3,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Pd.margin),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              spacing: Pd.s2,
              children: [
                Flexible(
                  child: Semantics(
                    header: true,
                    child: Text(
                      'DUE NEXT',
                      style: PdType.label.copyWith(color: Pd.textMuted),
                    ),
                  ),
                ),
                if (many)
                  ExcludeSemantics(
                    child: Text(
                      '${_index + 1} OF ${tickets.length}',
                      key: const ValueKey('vault-due-next-position'),
                      style: PdType.label.copyWith(color: Pd.textMuted),
                    ),
                  ),
              ],
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final full = constraints.maxWidth - Pd.margin * 2;
              // Leave the next ticket peeking in from the edge.
              final width = many
                  ? math.min(full - Pd.s8, Pd.maxContent / 2)
                  : full;
              _stride = width + Pd.s3;
              return SingleChildScrollView(
                key: const ValueKey('vault-due-next'),
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: Pd.margin),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: Pd.s3,
                    children: [
                      for (final ticket in tickets)
                        SizedBox(
                          key: ValueKey(ticket.key),
                          width: width,
                          child: VaultTicket(
                            key: ValueKey(
                              ticket.itemId != null
                                  ? 'vault-ticket-${ticket.itemId}'
                                  : 'vault-ticket-claim-${ticket.claimId}',
                            ),
                            number: ticket.number,
                            unit: ticket.unit,
                            kicker: ticket.kicker,
                            title: ticket.title,
                            body: ticket.body,
                            tone: ticket.tone,
                            semanticLabel: ticket.semanticLabel,
                            onTap: () => widget.onOpen(ticket),
                            onLongPress: () => widget.onHide(ticket),
                            onDismiss: () => widget.onHide(ticket),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
