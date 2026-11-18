import '../../../domain/formats.dart';
import '../../../domain/item_status.dart';
import '../../../domain/ladders.dart';
import '../../../domain/models/claim.dart';
import '../../../domain/models/shared_vault.dart';

enum ClaimsFilter { open, settled, all }

enum ClaimListStatus {
  waiting('WAITING', StampKind.waiting),
  noReply('NO REPLY', StampKind.escalate),
  documents('DOCS ASKED', StampKind.escalate),
  settled('SETTLED', StampKind.settled);

  const ClaimListStatus(this.label, this.stamp);

  final String label;
  final StampKind stamp;

  bool get needsAction => this == noReply || this == documents;
  bool get isOpen => this != settled;
}

class ClaimsListData {
  ClaimsListData(Iterable<ClaimListEntry> claims)
    : _claims = claims.toList()..sort(_compare);

  final List<ClaimListEntry> _claims;

  List<ClaimListEntry> visible(ClaimsFilter filter) => _claims
      .where(
        (claim) => switch (filter) {
          ClaimsFilter.open => claim.status.isOpen,
          ClaimsFilter.settled => !claim.status.isOpen,
          ClaimsFilter.all => true,
        },
      )
      .toList(growable: false);

  late final int openCount = _claims.where((claim) => claim.status.isOpen).length;
  int get settledCount => _claims.length - openCount;

  int count(ClaimsFilter filter) => switch (filter) {
    ClaimsFilter.open => openCount,
    ClaimsFilter.settled => settledCount,
    ClaimsFilter.all => _claims.length,
  };

  int get needsAction => _claims.where((claim) => claim.status.needsAction).length;

  ClaimListEntry? get featured =>
      _claims.where((claim) => claim.status.needsAction).firstOrNull;

  static int _compare(ClaimListEntry a, ClaimListEntry b) {
    final rank = _rank(a.status).compareTo(_rank(b.status));
    if (rank != 0) return rank;
    final byDate = a.status.isOpen
        ? a.orderDate.compareTo(b.orderDate)
        : b.orderDate.compareTo(a.orderDate);
    return byDate == 0 ? a.id.compareTo(b.id) : byDate;
  }

  static int _rank(ClaimListStatus status) => switch (status) {
    ClaimListStatus.noReply || ClaimListStatus.documents => 0,
    ClaimListStatus.waiting => 1,
    ClaimListStatus.settled => 2,
  };
}

class ClaimListEntry {
  const ClaimListEntry._({
    required this.id,
    required this.title,
    required this.metadata,
    required this.step,
    required this.next,
    required this.status,
    required this.day,
    required this.waitDays,
    required this.orderDate,
    required this.otherSide,
    this.hasDraft = false,
  });

  factory ClaimListEntry.local(Claim claim, DateTime today) {
    final status = switch (claim.status(today)) {
      ClaimStatus.waiting => ClaimListStatus.waiting,
      ClaimStatus.escalate => ClaimListStatus.noReply,
      ClaimStatus.settled => ClaimListStatus.settled,
    };
    final steps = ladderFor(claim.type);
    final current = stepTitle(claim.type, claim.step);
    final nextStep = claim.step + 1 < steps.length
        ? stepTitle(claim.type, claim.step + 1)
        : null;
    return ClaimListEntry._(
      id: claim.id,
      title: claim.title,
      metadata: [claim.type.caps, claim.itemLabel].join(' · '),
      step: _stepLabel(claim.step, steps.length, current),
      next: switch (status) {
        ClaimListStatus.settled => 'Settled on ${shortDate(claim.settledOn!)}',
        ClaimListStatus.noReply when nextStep != null => 'Next: $nextStep',
        _ when claim.nudgeDays <= 0 || status.needsAction =>
          'Next: Follow up with ${current.toLowerCase()}',
        _ => 'Follow up on ${shortDate(claim.nudgeOn)}',
      },
      status: status,
      day: claim.day(today),
      waitDays: daysBetween(claim.waitingSince, today).clamp(0, 1 << 30),
      orderDate: claim.settledOn ?? claim.waitingSince,
      otherSide: claim.step == 0 ? claim.type.otherSide : current.toUpperCase(),
    );
  }

  factory ClaimListEntry.shared(SharedClaim claim, DateTime today) {
    final status = switch (claim.state) {
      'no_reply' => ClaimListStatus.noReply,
      'docs_asked' => ClaimListStatus.documents,
      'settled' => ClaimListStatus.settled,
      _ => ClaimListStatus.waiting,
    };
    final lastReply = claim.lastHeard ?? claim.opened;
    final type = ClaimType.values.asNameMap()[claim.type];
    final current = claim.step == 0 && type != null
        ? firstRungTitle(type)
        : null;
    final next = claim.nextStep?.$1;
    return ClaimListEntry._(
      id: claim.id,
      title: claim.title,
      metadata: [
        type?.caps ?? 'OTHER CLAIM',
        if (claim.itemLabel.isNotEmpty) claim.itemLabel,
      ].join(' · '),
      step: _stepLabel(claim.step.clamp(0, 3), 4, current),
      next: switch (status) {
        ClaimListStatus.settled when claim.settled != null =>
          'Settled on ${shortDate(claim.settled!)}',
        ClaimListStatus.settled => 'Settled',
        _ when next != null => 'Next: $next',
        ClaimListStatus.documents => 'Next: Send the requested documents',
        ClaimListStatus.noReply => 'Next: Review your follow-up options',
        ClaimListStatus.waiting => 'Waiting for a reply',
      },
      status: status,
      day: claim.day(today),
      waitDays: daysBetween(lastReply, today).clamp(0, 1 << 30),
      orderDate: claim.settled ?? lastReply,
      otherSide: claim.step == 0 ? (type?.otherSide ?? '') : '',
      hasDraft: claim.draft != null,
    );
  }

  final String id;
  final String title;
  final String metadata;
  final String step;
  final String next;
  final ClaimListStatus status;
  final int day;
  final int waitDays;
  final DateTime orderDate;
  final String otherSide;
  final bool hasDraft;

  String get ticketKicker => switch (status) {
    ClaimListStatus.documents => 'NEEDS YOU · DOCUMENTS ASKED',
    _ when otherSide.isNotEmpty => 'NEEDS YOU · NO REPLY FROM $otherSide',
    _ => 'NEEDS YOU · NO REPLY',
  };

  String get ticketBody => switch (status) {
    ClaimListStatus.documents => 'They asked for documents. $next.',
    _ => 'No reply in ${daysWord(waitDays)}. '
        '${hasDraft ? 'Your draft is ready.' : 'Open the claim to see what comes next.'}',
  };

  static String _stepLabel(int step, int total, String? current) =>
      'STEP ${step + 1} OF $total'
      '${current == null ? '' : ' · ${current.toUpperCase()}'}';
}
