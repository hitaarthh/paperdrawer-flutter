import 'formats.dart';
import 'ladders.dart';
import 'models/claim.dart';
import 'models/item.dart';

class ClaimMessage {
  const ClaimMessage({
    required this.to,
    required this.subject,
    required this.body,
  });

  final String to;
  final String subject;
  final String body;

  String get full => 'To: $to\nSubject: $subject\n\n$body';
}

/// Drafts a message for the current rung using the facts currently in the drawer.
ClaimMessage draftMessage({
  required Claim claim,
  Item? item,
  required DateTime today,
}) {
  final details = item?.draft;
  final name = item?.name ?? claim.itemLabel;
  final kind = item?.kind;
  final from = details?.startsOn;
  final amount = details?.amountMinor;
  final source = details?.source.trim();
  final itemReference = details?.reference.trim();
  final noticed = claim.noticedOn;
  final reference = claim.reference.trim();
  final previousContact = claim.events
      .skipWhile((event) => event.kind != ClaimEventKind.step)
      .skip(1)
      .where((event) => event.kind == ClaimEventKind.sent)
      .firstOrNull;

  final facts = [
    if (source != null && source.isNotEmpty)
      '${kind == ItemKind.policy ? 'Insurer' : 'Store or issuer'}: $source',
    if (from != null)
      '${kind == ItemKind.bill ? 'Purchase date' : 'Start date'}: ${longDate(from)}',
    if (amount != null)
      '${kind == ItemKind.policy ? 'Premium' : 'Amount paid'}: ${money(amount, details!.currency)}',
    if (itemReference != null && itemReference.isNotEmpty)
      '${_referenceLabel(kind)}: $itemReference',
    if (reference.isNotEmpty) 'Support or claim reference: $reference',
  ];

  final paragraphs = [
    'Hello,',
    'I’m writing about my ${claim.type.noun} claim for $name.',
    if (claim.step > 0)
      _followUp(claim, today, previousContact),
    if (facts.isNotEmpty) facts.join('\n'),
    if (claim.problem.trim().isNotEmpty) claim.problem.trim(),
    if (noticed != null) 'I first noticed the issue on ${longDate(noticed)}.',
    'I’d appreciate ${claim.want.phrase}. Please let me know the next steps.',
    'Thank you,',
  ];
  return ClaimMessage(
    to: ladderFor(claim.type)[claim.step].recipient,
    subject: claim.step == 0
        ? claim.title
        : 'Follow-up on my ${claim.title}',
    body: paragraphs.join('\n\n'),
  );
}

String _referenceLabel(ItemKind? kind) => switch (kind) {
  ItemKind.bill => 'Invoice number',
  ItemKind.policy => 'Policy number',
  _ => 'Document reference',
};

String _followUp(Claim claim, DateTime today, ClaimEvent? previousContact) {
  final previousStep = stepTitle(claim.type, claim.step - 1);
  final days = daysBetween(previousContact?.on ?? claim.openedOn, today);
  final timing = days > 0
      ? ' The issue has been unresolved for ${daysWord(days)}.'
      : '';
  if (previousContact != null) {
    return 'I previously contacted $previousStep on '
        '${longDate(previousContact.on)}.$timing';
  }
  return 'My claim began on ${longDate(claim.openedOn)}. '
      'The previous step was $previousStep.$timing';
}
