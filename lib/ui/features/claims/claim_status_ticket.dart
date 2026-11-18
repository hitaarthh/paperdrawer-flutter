import 'package:flutter/widgets.dart';

import '../../../domain/formats.dart';
import '../../../domain/ladders.dart';
import '../../../domain/models/claim.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/type.dart';

class ClaimStatusTicket extends StatelessWidget {
  const ClaimStatusTicket({required this.claim, required this.today, super.key});

  final Claim claim;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final steps = ladderFor(claim.type);
    final current = stepTitle(claim.type, claim.step);
    final days = claim.waitingDays(today);
    final shouldEscalate = recommendedStepFor(claim, today) != null;
    final isFinal = claim.step + 1 == steps.length;
    final ink = shouldEscalate ? Pd.onLime : Pd.text;
    final supporting = shouldEscalate ? Pd.ink2 : Pd.textMuted;
    final heading = switch ((shouldEscalate, isFinal)) {
      (true, _) => 'Time to go one step up',
      (_, true) => 'Final step',
      _ => 'Waiting for a response',
    };
    final detail = switch ((shouldEscalate, isFinal)) {
      (true, _) => 'Waiting since ${shortDate(claim.waitingSince)}. '
          'Your draft for the next step is ready below.',
      (_, true) => 'Use the draft below or log an update as your claim progresses.',
      _ => 'If you’re still waiting on ${shortDate(claim.nudgeOn)}, '
          'your next step is ${stepTitle(claim.type, claim.step + 1)}.',
    };

    return RepaintBoundary(
      child: CustomPaint(
        painter: _TicketPainter(shouldEscalate),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Pd.s12 * 2 + Pd.s5),
          child: Row(
            children: [
              SizedBox(
                width: _TicketPainter.stubWidth,
                child: Padding(
                  padding: const EdgeInsets.all(Pd.s3),
                  child: Semantics(
                    label: '${daysWord(days)} waiting',
                    excludeSemantics: true,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('$days', style: PdType.ticketNumber.copyWith(color: ink)),
                        ),
                        Text(days == 1 ? 'DAY' : 'DAYS', style: PdType.label.copyWith(color: ink)),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Pd.s4, vertical: Pd.s3),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: Pd.s1,
                    children: [
                      Text(
                        'STEP ${claim.step + 1} OF ${steps.length} · '
                        '${shouldEscalate ? 'NO REPLY FROM ' : ''}${current.toUpperCase()}',
                        style: PdType.label.copyWith(color: supporting),
                      ),
                      Text(heading, style: PdType.cardTitle.copyWith(color: ink)),
                      Text(detail, style: PdType.footnote.copyWith(color: supporting)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TicketPainter extends CustomPainter {
  const _TicketPainter(this.urgent);

  static const stubWidth = Pd.s12 * 2 + Pd.s5;
  static const _notchRadius = Pd.s2 + 2;
  final bool urgent;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Path()..addRRect(RRect.fromRectAndRadius(
      Offset.zero & size, const Radius.circular(Pd.rSm),
    ));
    final midY = size.height / 2;
    final notches = Path()
      ..addOval(Rect.fromCircle(center: Offset(0, midY), radius: _notchRadius))
      ..addOval(Rect.fromCircle(center: Offset(size.width, midY), radius: _notchRadius));
    final ticket = Path.combine(PathOperation.difference, bounds, notches);
    canvas.drawPath(ticket, Paint()..color = urgent ? Pd.lime : Pd.surface2);
    final dash = Paint()
      ..color = urgent ? Pd.ink.withValues(alpha: 0.3) : Pd.line
      ..strokeWidth = 2;
    canvas.save();
    canvas.clipPath(ticket);
    for (var y = 0.0; y < size.height; y += Pd.s2) {
      canvas.drawLine(Offset(stubWidth, y), Offset(stubWidth, y + Pd.s1), dash);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TicketPainter oldDelegate) => oldDelegate.urgent != urgent;
}
