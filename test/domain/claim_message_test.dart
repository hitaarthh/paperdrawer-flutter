import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrawer/domain/claim_message.dart';
import 'package:paperdrawer/domain/formats.dart';
import 'package:paperdrawer/domain/ladders.dart';
import 'package:paperdrawer/domain/models/claim.dart';

void main() {
  test('a recommended draft uses the previous contact and keeps the current step', () {
    final opened = DateTime.utc(2026, 11, 4);
    final sent = addDays(opened, 2);
    final claim = Claim(
      id: 'claim',
      type: ClaimType.repair,
      want: ClaimWant.repair,
      itemLabel: 'Laptop',
      problem: 'The hinge cracked & won’t close.',
      openedOn: opened,
      stepSince: opened,
      step: 0,
      events: [
        ClaimEvent(id: 'sent', on: sent, kind: ClaimEventKind.sent, text: 'Sent'),
      ],
    );
    final due = addDays(sent, 14);
    expect(recommendedStepFor(claim, addDays(due, -1)), isNull);
    final next = recommendedStepFor(claim, due);
    expect(next, 1);

    final draft = draftMessage(claim: claim, today: due, forStep: next);
    expect(draft.to, 'Grievance officer');
    expect(draft.body, contains('contacted Brand support on 6 Nov 2026'));
    expect(draft.mailto.path, isEmpty);
    expect(draft.mailto.queryParameters, {'subject': draft.subject, 'body': draft.body});
    expect(draft.mailto.toString(), isNot(contains('+')));
    expect(claim.step, 0);
  });
}
