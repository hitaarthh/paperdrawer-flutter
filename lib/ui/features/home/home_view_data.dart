import '../../../domain/item_status.dart';
import '../../../domain/models/claim.dart';
import '../../../domain/models/item.dart';
import '../vault/vault_tickets.dart';

class HomeViewData {
  HomeViewData({
    required List<Item> items,
    required List<Claim> claims,
    required this.today,
  }) : openClaims = claims.where((claim) => claim.isOpen).toList()
         ..sort(_compareClaims),
       _deadlines = _dueDeadlines(items, today);

  final DateTime today;
  final List<Claim> openClaims;
  final List<(ItemSummary, CoverWindow)> _deadlines;

  int get dueCount => _deadlines.length;

  List<VaultTicketData> get tickets => [
    for (final (index, (summary, window)) in _deadlines.take(2).indexed)
      _ticket(summary, window, urgent: index == 0),
  ];

  static VaultTicketData _ticket(
    ItemSummary summary,
    CoverWindow window, {
    required bool urgent,
  }) {
    final ticket = VaultTicketData.window(
      summary,
      window,
      '${summary.item.id}/${window.type.name}',
    );
    return urgent ? ticket.asMostUrgent() : ticket;
  }

  static List<(ItemSummary, CoverWindow)> _dueDeadlines(
    List<Item> items,
    DateTime today,
  ) {
    final summaries = [
      for (final item in items)
        if (!item.isArchived) ItemSummary.of(item, today),
    ];
    return [
      for (final summary in summaries)
        for (final window in summary.windows)
          if (window.isDue(today)) (summary, window),
    ]..sort((a, b) {
      final byDate = a.$2.end.compareTo(b.$2.end);
      if (byDate != 0) return byDate;
      final byItem = a.$1.item.id.compareTo(b.$1.item.id);
      return byItem == 0 ? a.$2.type.index.compareTo(b.$2.type.index) : byItem;
    });
  }

  static int _compareClaims(Claim a, Claim b) {
    final aFollowUp = a.followUp;
    final bFollowUp = b.followUp;
    if (aFollowUp != null && bFollowUp != null) {
      final byReminder = aFollowUp.compareTo(bFollowUp);
      if (byReminder != 0) return byReminder;
    } else if (aFollowUp != null || bFollowUp != null) {
      return aFollowUp != null ? -1 : 1;
    }
    return (b.events.firstOrNull?.on ?? b.openedOn).compareTo(
      a.events.firstOrNull?.on ?? a.openedOn,
    );
  }
}
