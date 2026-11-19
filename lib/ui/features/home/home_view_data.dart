import '../../../domain/formats.dart';
import '../../../domain/item_status.dart';
import '../../../domain/models/claim.dart';
import '../../../domain/models/item.dart';
import '../../../domain/models/ledger.dart';
import '../../../domain/models/shared_vault.dart';
import '../vault/vault_tickets.dart';

class HomeClaimData {
  HomeClaimData.local(Claim claim)
    : id = claim.id,
      title = claim.title,
      category = claim.type.caps,
      opened = claim.openedOn,
      settled = claim.settledOn,
      isOpen = claim.isOpen,
      followUp = claim.followUp,
      entries = claim.ledger;

  HomeClaimData.shared(SharedClaim claim)
    : id = claim.id,
      title = claim.title,
      category = switch (claim.type) {
        'repair' => 'WARRANTY REPAIR',
        'refund' => 'RETURN & REFUND',
        'insurance' => 'INSURANCE CLAIM',
        _ => 'CLAIM',
      },
      opened = claim.opened,
      settled = claim.settled,
      isOpen = claim.state != 'settled' && claim.settled == null,
      followUp = claim.followUp,
      entries = claim.ledger;

  final String id;
  final String title;
  final String category;
  final DateTime opened;
  final DateTime? settled;
  final bool isOpen;
  final DateTime? followUp;
  final List<LedgerEntry> entries;
}

class HomeViewData {
  HomeViewData({
    required List<Item> items,
    required List<HomeClaimData> claims,
    required DateTime today,
    required DateTime now,
  }) : openClaims = claims.where((claim) => claim.isOpen).toList()
         ..sort(_compareClaims),
       tickets = _upcomingTickets(items, today, now);

  final List<HomeClaimData> openClaims;
  final List<VaultTicketData> tickets;

  static List<VaultTicketData> _upcomingTickets(
    List<Item> items,
    DateTime today,
    DateTime now,
  ) {
    final upcoming = <(DateTime, VaultTicketData)>[];
    for (final item in items) {
      if (item.isArchived) continue;
      final summary = ItemSummary.of(item, today);
      final window = summary.next;
      if (window != null) {
        if (window.daysLeft(today) <= ticketWithinDays) {
          upcoming.add((
            window.end,
            VaultTicketData.window(
              summary,
              window,
              '${item.id}/${window.type.name}',
            ),
          ));
        }
        continue;
      }
      final at = item.draft.reminderAt?.toLocal();
      if (item.draft.remind &&
          at != null &&
          at.isAfter(now) &&
          daysBetween(today, civil(at)) <= ticketWithinDays) {
        upcoming.add((civil(at), VaultTicketData.reminder(item, at, today)));
      }
    }
    upcoming.sort((a, b) {
      final byDate = a.$1.compareTo(b.$1);
      return byDate == 0 ? a.$2.key.compareTo(b.$2.key) : byDate;
    });
    return [
      for (final (date, ticket) in upcoming)
        daysBetween(today, date) <= 7 ? ticket.asMostUrgent() : ticket,
    ];
  }

  static int _compareClaims(HomeClaimData a, HomeClaimData b) {
    final aFollowUp = a.followUp;
    final bFollowUp = b.followUp;
    if (aFollowUp != null && bFollowUp != null) {
      final byReminder = aFollowUp.compareTo(bFollowUp);
      if (byReminder != 0) return byReminder;
    } else if (aFollowUp != null || bFollowUp != null) {
      return aFollowUp != null ? -1 : 1;
    }
    return (b.entries.firstOrNull?.date ?? b.opened).compareTo(
      a.entries.firstOrNull?.date ?? a.opened,
    );
  }
}
