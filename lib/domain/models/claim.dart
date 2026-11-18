import 'package:flutter/foundation.dart';

import '../formats.dart';

enum ClaimType {
  repair('REPAIR UNDER WARRANTY', 'WARRANTY REPAIR', 'repair', 'BRAND'),
  refund('RETURN & REFUND', 'RETURN & REFUND', 'return', 'SELLER'),
  insurance('INSURANCE CLAIM', 'INSURANCE CLAIM', 'insurance', 'INSURER');

  const ClaimType(this.choice, this.caps, this.noun, this.otherSide);

  /// Label on the "Start a claim" form.
  final String choice;

  /// Kicker on lists and the claim header.
  final String caps;

  /// "Laptop repair claim"
  final String noun;

  /// Who the user is waiting on.
  final String otherSide;
}

enum ClaimWant {
  repair('REPAIR', 'a repair'),
  replacement('REPLACEMENT', 'a replacement'),
  refund('REFUND', 'a full refund'),
  payout('CLAIM PAYOUT', 'settlement of my claim');

  const ClaimWant(this.chip, this.phrase);

  final String chip;
  final String phrase;
}

/// WAITING: the other side has time to reply. ESCALATE: no reply within the
/// expected days, so the next rung is ready. SETTLED: done.
enum ClaimStatus { waiting, escalate, settled }

enum ClaimEventKind { opened, sent, reply, step, note, settled, reopened }

@immutable
class ClaimEvent {
  const ClaimEvent({
    required this.id,
    required this.on,
    required this.kind,
    required this.text,
  });

  final String id;
  final DateTime on;
  final ClaimEventKind kind;
  final String text;
}

@immutable
class Claim {
  const Claim({
    required this.id,
    required this.type,
    required this.want,
    required this.itemLabel,
    required this.problem,
    required this.openedOn,
    required this.step,
    required this.stepSince,
    this.itemId,
    this.reference = '',
    this.noticedOn,
    this.lastHeardOn,
    this.settledOn,
    this.nudgeDays = 14,
    this.events = const [],
  });

  final String id;

  /// Null once the item it was about has been deleted.
  final String? itemId;

  /// Snapshot of the item's name, so the claim still reads well on its own.
  final String itemLabel;
  final ClaimType type;
  final ClaimWant want;
  final String problem;
  final String reference;
  final DateTime openedOn;
  final DateTime? noticedOn;

  /// Current rung of the ladder, 0-based.
  final int step;

  /// When the user reached the current rung.
  final DateTime stepSince;
  final DateTime? lastHeardOn;
  final DateTime? settledOn;

  /// Suggest the next rung if nobody replies within this many days.
  final int nudgeDays;

  /// Newest first.
  final List<ClaimEvent> events;

  bool get isOpen => settledOn == null;

  String get title => '$itemLabel ${type.noun} claim';

  /// The last reply, sent message or step change, whichever is later.
  DateTime get waitingSince {
    final heard = lastHeardOn;
    var since = heard != null && heard.isAfter(stepSince) ? heard : stepSince;
    for (final event in events) {
      if (event.kind == ClaimEventKind.sent && event.on.isAfter(since)) {
        since = event.on;
      }
    }
    return since;
  }

  ClaimStatus status(DateTime today) {
    if (!isOpen) return ClaimStatus.settled;
    return nudgeDays > 0 && daysBetween(waitingSince, today) >= nudgeDays
        ? ClaimStatus.escalate
        : ClaimStatus.waiting;
  }

  /// "day 14": days since the claim was opened, or how long it took.
  int day(DateTime today) {
    final end = settledOn ?? today;
    final days = daysBetween(openedOn, end);
    return days < 0 ? 0 : days;
  }

  DateTime get nudgeOn => addDays(waitingSince, nudgeDays);
}
