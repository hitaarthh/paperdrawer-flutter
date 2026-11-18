import 'models/claim.dart';

/// One rung of an escalation route. These are suggestions: PaperDrawer never
/// contacts anyone for the user.
class LadderStep {
  const LadderStep({
    required this.title,
    required this.guidance,
    required this.recipient,
    this.waitDays = 14,
    this.phone,
    this.url,
    this.urlLabel,
  });

  final String title;
  final String guidance;

  /// Who the drafted message is addressed to.
  final String recipient;

  /// How long to give them before suggesting the next rung.
  final int waitDays;
  final String? phone;
  final String? url;
  final String? urlLabel;
}

/// India-first routes, from the PaperDrawer mobile design.
const _consumerLadder = [
  LadderStep(
    title: 'Brand or seller support',
    guidance: 'Raise a request and note the ticket number.',
    recipient: 'Customer support',
  ),
  LadderStep(
    title: 'Grievance officer',
    guidance: 'Write to the grievance officer listed on their website.',
    recipient: 'Grievance officer',
    waitDays: 30,
  ),
  LadderStep(
    title: 'National Consumer Helpline',
    guidance: 'Call 1915 or file on consumerhelpline.gov.in.',
    recipient: 'National Consumer Helpline',
    waitDays: 30,
    phone: '1915',
    url: 'https://consumerhelpline.gov.in',
    urlLabel: 'OPEN HELPLINE',
  ),
  LadderStep(
    title: 'Consumer commission',
    guidance: 'File on e-Jagriti if the helpline route fails.',
    recipient: 'District Consumer Commission',
    waitDays: 0,
    url: 'https://e-jagriti.gov.in',
    urlLabel: 'OPEN E-JAGRITI',
  ),
];

const _insuranceLadder = [
  LadderStep(
    title: 'Insurer or TPA',
    guidance: 'Submit the claim with documents and note the claim number.',
    recipient: 'Claims team',
  ),
  LadderStep(
    title: 'Grievance officer',
    guidance: "Write to the insurer's grievance redressal officer.",
    recipient: 'Grievance redressal officer',
    waitDays: 15,
  ),
  LadderStep(
    title: 'IRDAI Bima Bharosa',
    guidance: 'Register the complaint on Bima Bharosa or call 155255.',
    recipient: 'IRDAI Bima Bharosa',
    waitDays: 30,
    phone: '155255',
    url: 'https://bimabharosa.irdai.gov.in',
    urlLabel: 'OPEN BIMA BHAROSA',
  ),
  LadderStep(
    title: 'Insurance Ombudsman',
    guidance: 'Apply to the Insurance Ombudsman for your area.',
    recipient: 'Insurance Ombudsman',
    waitDays: 0,
    url: 'https://www.cioins.co.in',
    urlLabel: 'OPEN OMBUDSMAN',
  ),
];

List<LadderStep> ladderFor(ClaimType type) =>
    type == ClaimType.insurance ? _insuranceLadder : _consumerLadder;

/// The first rung names the other side for the claim type.
String firstRungTitle(ClaimType type) => switch (type) {
  ClaimType.repair => 'Brand support',
  ClaimType.refund => 'Seller support',
  ClaimType.insurance => 'Insurer or TPA',
};

String stepTitle(ClaimType type, int step) =>
    step == 0 ? firstRungTitle(type) : ladderFor(type)[step].title;
