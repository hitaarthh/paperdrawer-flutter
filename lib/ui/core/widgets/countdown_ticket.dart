import 'package:cupertino_ui/cupertino_ui.dart';

import '../../../domain/item_status.dart';
import '../theme/tokens.dart';
import '../theme/type.dart';

class CountdownTicket extends StatefulWidget {
  const CountdownTicket({
    required this.summary,
    required this.window,
    required this.onTap,
    this.onDismissed,
    super.key,
  });

  final ItemSummary summary;
  final CoverWindow window;
  final VoidCallback onTap;
  final VoidCallback? onDismissed;

  @override
  State<CountdownTicket> createState() => _CountdownTicketState();
}

class _CountdownTicketState extends State<CountdownTicket> {
  static const _stubWidth = 100.0;
  bool _dismissed = false;

  @override
  void didUpdateWidget(CountdownTicket oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.summary.item.id != widget.summary.item.id ||
        oldWidget.summary.today != widget.summary.today ||
        oldWidget.window.type != widget.window.type ||
        oldWidget.window.end != widget.window.end) {
      _dismissed = false;
    }
  }

  void _dismiss() {
    setState(() => _dismissed = true);
    widget.onDismissed?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();
    final summary = widget.summary;
    final window = widget.window;
    final days = window.daysLeft(summary.today);
    final dismissible = widget.onDismissed != null;
    final ticket = Semantics(
      button: true,
      label: '${summary.item.name}, ${window.fact(summary.today)}',
      onTap: widget.onTap,
      onDismiss: dismissible ? _dismiss : null,
      excludeSemantics: true,
      child: CupertinoButton(
        onPressed: widget.onTap,
        padding: EdgeInsets.zero,
        pressedOpacity: 0.7,
        focusColor: Pd.lime,
        child: RepaintBoundary(
          child: CustomPaint(
            painter: const _TicketPainter(_stubWidth),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: Pd.s12 * 2 + Pd.s6),
              child: Row(
                children: [
                  SizedBox(
                    width: _stubWidth,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Pd.s2,
                        vertical: Pd.s3,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              days > 0 ? '$days' : 'TODAY',
                              style:
                                  (days > 0
                                          ? PdType.ticketNumber
                                          : PdType.title1)
                                      .copyWith(color: Pd.ink),
                            ),
                          ),
                          if (days > 0)
                            Text(
                              days == 1 ? 'DAY' : 'DAYS',
                              style: PdType.label.copyWith(color: Pd.ink),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Pd.s5,
                        vertical: Pd.s4,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        spacing: Pd.s1,
                        children: [
                          Text(
                            window.ticketKicker,
                            style: PdType.label.copyWith(color: Pd.dueInk),
                          ),
                          Text(
                            summary.item.name,
                            style: PdType.cardTitle.copyWith(color: Pd.ink),
                          ),
                          Text(
                            window.action(),
                            style: PdType.callout.copyWith(color: Pd.ink2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return dismissible
        ? Dismissible(
            key: ValueKey((summary.item.id, window.type, window.end)),
            direction: DismissDirection.horizontal,
            onDismissed: (_) => _dismiss(),
            child: ticket,
          )
        : ticket;
  }
}

class _TicketPainter extends CustomPainter {
  const _TicketPainter(this.perforation);

  final double perforation;

  @override
  void paint(Canvas canvas, Size size) {
    const notchRadius = 10.0;
    final bounds = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(Pd.rSm),
        ),
      );
    final notches = Path()
      ..addOval(
        Rect.fromCircle(center: Offset(perforation, 0), radius: notchRadius),
      )
      ..addOval(
        Rect.fromCircle(
          center: Offset(perforation, size.height),
          radius: notchRadius,
        ),
      );
    final paper = Path.combine(PathOperation.difference, bounds, notches);
    for (final shadow in Pd.shadowPaper) {
      canvas.drawPath(paper.shift(shadow.offset), shadow.toPaint());
    }
    canvas.drawPath(paper, Paint()..color = Pd.paper);
    final dash = Paint()
      ..color = Pd.paperDash
      ..strokeWidth = 2;
    final bottom = size.height - notchRadius;
    for (double y = notchRadius; y < bottom; y += Pd.s2) {
      canvas.drawLine(
        Offset(perforation, y),
        Offset(perforation, (y + Pd.s1).clamp(notchRadius, bottom)),
        dash,
      );
    }
  }

  @override
  bool shouldRepaint(_TicketPainter oldDelegate) =>
      oldDelegate.perforation != perforation;
}
