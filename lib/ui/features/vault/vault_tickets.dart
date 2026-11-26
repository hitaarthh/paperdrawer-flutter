import 'package:flutter/foundation.dart';

import '../../../domain/formats.dart';
import '../../../domain/item_status.dart';
import '../../../domain/models/item.dart';
import '../../core/widgets/vault_ticket.dart';

export '../../core/widgets/vault_ticket.dart' show VaultTicketTone;

/// One ticket in the vault's "Due next" strip: a cover window that closes
/// soon, or a reminder set on an item.
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
    required this.itemId,
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

  factory VaultTicketData.reminder(Item item, DateTime at, DateTime today) {
    final date = civil(at);
    final days = daysBetween(today, date);
    final when = longDate(date);
    return VaultTicketData._(
      key: '${item.id}/reminder',
      number: days == 0 ? 'TODAY' : days.toString().padLeft(2, '0'),
      unit: days == 0 ? null : (days == 1 ? 'DAY' : 'DAYS'),
      kicker: 'REMINDER · ${_dayCaps(date)}',
      title: item.name,
      body: when,
      tone: VaultTicketTone.paper,
      semanticLabel: '${item.name}, reminder on $when.',
      itemId: item.id,
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
  final String itemId;

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
  );
}

const _weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

/// "FRI 20 NOV"
String _dayCaps(DateTime date) =>
    '${_weekdays[date.weekday - 1]} ${shortDate(date).toUpperCase()}';

String _windowNudge(CoverWindow window) => switch (window.type) {
  WindowType.returnWindow => 'Not happy with it? Start the return now.',
  WindowType.warranty ||
  WindowType.componentWarranty => 'Book a service visit while it’s covered.',
  WindowType.policyYear =>
    window.renews
        ? 'Renew before it lapses.'
        : 'Check when your coverage ends.',
  WindowType.validity => 'Renew it before it runs out.',
  WindowType.term =>
    window.renews ? 'Renew before it lapses.' : 'Plan for what comes next.',
};
