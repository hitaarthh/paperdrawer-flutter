import 'package:flutter/widgets.dart';

import '../../../domain/formats.dart';
import '../../../domain/ladders.dart';
import '../../../domain/models/claim.dart';
import '../../core/widgets/vault_ticket.dart';

class ClaimStatusTicket extends StatelessWidget {
  const ClaimStatusTicket({
    required this.claim,
    required this.today,
    super.key,
  });

  final Claim claim;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final steps = ladderFor(claim.type);
    final current = stepTitle(claim.type, claim.step);
    final days = claim.waitingDays(today);
    final shouldEscalate = recommendedStepFor(claim, today) != null;
    final isFinal = claim.step + 1 == steps.length;
    final heading = switch ((shouldEscalate, isFinal)) {
      (true, _) => 'Time to go one step up',
      (_, true) => 'Final step',
      _ => 'Waiting for a response',
    };
    final detail = switch ((shouldEscalate, isFinal)) {
      (true, _) =>
        'Waiting since ${shortDate(claim.waitingSince)}. '
            'Your draft for the next step is ready below.',
      (_, true) =>
        'Use the draft below or log an update as your claim progresses.',
      _ =>
        'If you’re still waiting on ${shortDate(claim.nudgeOn)}, '
            'your next step is ${stepTitle(claim.type, claim.step + 1)}.',
    };
    final position = 'Step ${claim.step + 1} of ${steps.length}';
    final contact = shouldEscalate ? 'No reply from $current' : current;

    return VaultTicket(
      number: '$days',
      unit: days == 1 ? 'DAY' : 'DAYS',
      kicker: '$position · $contact'.toUpperCase(),
      title: heading,
      body: detail,
      tone: shouldEscalate ? VaultTicketTone.lime : VaultTicketTone.paper,
      semanticLabel:
          '${daysWord(days)} waiting. $position. $contact. $heading. $detail',
    );
  }
}
