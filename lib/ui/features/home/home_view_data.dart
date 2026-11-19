import '../../../domain/formats.dart';
import '../../../domain/item_status.dart';
import '../../../domain/models/item.dart';
import '../vault/vault_tickets.dart';

class HomeViewData {
  HomeViewData({
    required List<Item> items,
    required DateTime today,
    required DateTime now,
  }) : tickets = _upcomingTickets(items, today, now);

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
}
