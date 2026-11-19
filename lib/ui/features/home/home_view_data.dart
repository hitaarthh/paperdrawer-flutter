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
    required this.today,
  }) : openClaims = claims.where((claim) => claim.isOpen).toList()
         ..sort(_compareClaims),
       _deadlines = _dueDeadlines(items, today);

  final DateTime today;
  final List<HomeClaimData> openClaims;
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
