import 'package:flutter/foundation.dart';

import '../../../domain/formats.dart';
import '../../../domain/item_status.dart';
import '../../../domain/models/claim.dart';
import '../../core/widgets/vault_ticket.dart';

export '../../core/widgets/vault_ticket.dart' show VaultTicketTone;

/// One ticket in the vault's "Due next" strip: a cover window that closes
/// soon, or a claim that has waited long enough to go one step up.
@immutable
class VaultTicketData {
  const VaultTicketData._({
    required this.key,
    required this.number,
    required this.unit,
    required this.kicker,
    required this.title,
    required this.body,
    required this.tone,
    required this.semanticLabel,
    this.itemId,
    this.claimId,
  });

  factory VaultTicketData.window(
    ItemSummary summary,
    CoverWindow window,
    String key,
  ) {
    final days = window.daysLeft(summary.today);
    return VaultTicketData._(
      key: key,
      number: days == 0 ? 'TODAY' : days.toString().padLeft(2, '0'),
      unit: days == 0 ? null : (days == 1 ? 'DAY' : 'DAYS'),
      kicker: '${window.ticketKicker} · ${_dayCaps(window.end)}',
      title: summary.item.name,
      body: _windowNudge(window),
      tone: VaultTicketTone.paper,
      semanticLabel:
          '${summary.item.name}, ${window.fact(summary.today)}. '
          '${window.action()}.',
      itemId: summary.item.id,
    );
  }

  factory VaultTicketData.claim(Claim claim, DateTime today, String key) {
    final days = daysBetween(claim.waitingSince, today).clamp(0, 999);
    return VaultTicketData._(
      key: key,
      number: days.toString().padLeft(2, '0'),
      unit: days == 1 ? 'DAY' : 'DAYS',
      kicker: 'CLAIM · NO REPLY FROM ${claim.type.otherSide}',
      title: claim.title,
      body: 'Time to go one step up.',
      tone: VaultTicketTone.lime,
      semanticLabel:
          '${claim.title}, no reply for ${daysWord(days)}. '
          'Time to go one step up.',
      claimId: claim.id,
    );
  }

  /// Dismissal key; carries today's date so a hidden ticket returns tomorrow.
  final String key;

  /// "02", or "TODAY" on the last day.
  final String number;
  final String? unit;
  final String kicker;
  final String title;
  final String body;
  final VaultTicketTone tone;
  final String semanticLabel;
  final String? itemId;
  final String? claimId;

  /// The soonest deadline is printed in signal orange.
  VaultTicketData asMostUrgent() => VaultTicketData._(
    key: key,
    number: number,
    unit: unit,
    kicker: kicker,
    title: title,
    body: body,
    tone: VaultTicketTone.signal,
    semanticLabel: semanticLabel,
    itemId: itemId,
    claimId: claimId,
  );
}

const _weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

/// "FRI 20 NOV"
String _dayCaps(DateTime date) =>
    '${_weekdays[date.weekday - 1]} ${shortDate(date).toUpperCase()}';

String _windowNudge(CoverWindow window) => switch (window.type) {
  WindowType.returnWindow => 'Not happy with it? Start the return now.',
  WindowType.warranty => 'Book a service visit while it’s covered.',
  WindowType.policyYear => 'Renew before it lapses.',
  WindowType.validity => 'Renew it before it runs out.',
  WindowType.term =>
    window.renews ? 'Renew before it lapses.' : 'Plan for what comes next.',
};
