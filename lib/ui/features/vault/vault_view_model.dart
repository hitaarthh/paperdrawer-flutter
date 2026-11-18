import 'package:flutter/foundation.dart';

import '../../../data/repositories/claim_repository.dart';
import '../../../data/repositories/item_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../data/services/today.dart';
import '../../../domain/formats.dart';
import '../../../domain/item_status.dart';
import '../../../domain/models/claim.dart';
import 'vault_tickets.dart';

export 'vault_tickets.dart';

class VaultViewModel extends ChangeNotifier {
  VaultViewModel(this._items, this._claims, this._settings, this._today)
    : _knownIds = _items.items.map((item) => item.id).toSet() {
    _items.addListener(_reload);
    _claims.addListener(_reload);
    _settings.addListener(_reload);
    _today.addListener(_reload);
    _reload();
  }

  final ItemRepository _items;
  final ClaimRepository _claims;
  final SettingsRepository _settings;
  final Today _today;
  Set<String> _knownIds;
  String? _landOn;
  String? _dismissing;
  bool _disposed = false;
  bool _oldestFirst = false;
  VaultFilter _filter = VaultFilter.all;
  String _query = '';
  List<ItemSummary> _summaries = [];

  VaultFilter get filter => _filter;
  bool get oldestFirst => _oldestFirst;
  String get query => _query;
  int get activeCount => _summaries.length;
  bool get atLimit => _items.atLimit;

  /// "010 ITEMS · 4 DUE SOON · 3 OPEN CLAIMS", over the hero title.
  String get kicker {
    final due = _summaries.where(VaultFilter.due.matches).length;
    final open = _claims.claims.where((claim) => claim.isOpen).length;
    return [
      '${activeCount.toString().padLeft(3, '0')} '
          '${activeCount == 1 ? 'ITEM' : 'ITEMS'}',
      due == 0 ? 'NOTHING DUE' : '$due DUE SOON',
      if (open > 0) '$open OPEN ${open == 1 ? 'CLAIM' : 'CLAIMS'}',
    ].join(' · ');
  }

  /// Tab counts follow the search, so they always match the list.
  int count(VaultFilter filter) =>
      _searched.where(filter.matches).length;

  List<ItemSummary> get visible {
    final items = _searched.where(_filter.matches).toList();
    if (_oldestFirst) {
      items.sort((a, b) => a.item.createdAt.compareTo(b.item.createdAt));
    }
    return items;
  }

  Iterable<ItemSummary> get _searched {
    final words = _query.toLowerCase().split(' ').where((w) => w.isNotEmpty);
    if (words.isEmpty) return _summaries;
    return _summaries.where((summary) {
      final d = summary.d;
      final haystack = [
        summary.item.name,
        d.source,
        d.subtype,
        d.reference,
        summary.item.kind.label,
      ].join(' ').toLowerCase();
      return words.every(haystack.contains);
    });
  }

  /// The "Due next" strip: deadlines within [ticketWithinDays], soonest
  /// first, then claims waiting on a reply long enough to escalate.
  List<VaultTicketData> get tickets {
    final today = _today.value;
    final hidden = {
      ...?_settings.ticketDismissedKey?.split(_keySeparator),
      ?_dismissing,
    };
    final dated = [
      for (final summary in _summaries)
        if (summary.next case final window?
            when window.daysLeft(summary.today) <= ticketWithinDays)
          (summary, window),
    ]..sort((a, b) => a.$2.end.compareTo(b.$2.end));
    final result = <VaultTicketData>[
      for (final (summary, window) in dated)
        VaultTicketData.window(summary, window, ticketKey(summary, window)),
      for (final claim in _claims.claims)
        if (claim.status(today) == ClaimStatus.escalate)
          VaultTicketData.claim(claim, today, _claimKey(claim, today)),
    ].where((ticket) => !hidden.contains(ticket.key)).take(maxTickets).toList();
    if (result.isNotEmpty && result.first.itemId != null) {
      result[0] = result.first.asMostUrgent();
    }
    return result;
  }

  static const maxTickets = 5;
  static const _keySeparator = '|';

  String ticketKey(ItemSummary summary, CoverWindow window) =>
      '${isoDate(summary.today)}/${summary.item.id}/${window.type.name}/${isoDate(window.end)}';

  String _claimKey(Claim claim, DateTime today) =>
      '${isoDate(today)}/claim/${claim.id}/${isoDate(claim.waitingSince)}';

  /// Hides a ticket for today. Keys carry the day, so only today's are kept.
  Future<void> dismissTicket(String key) async {
    final day = key.split('/').first;
    final kept = (_settings.ticketDismissedKey?.split(_keySeparator) ?? [])
        .where((old) => old.startsWith('$day/') && old != key);
    _dismissing = key;
    notifyListeners();
    try {
      await _settings.dismissTicket([...kept, key].join(_keySeparator));
    } finally {
      _dismissing = null;
      if (!_disposed) notifyListeners();
    }
  }

  bool shouldLand(String id) => _landOn == id;

  void landed(String id) {
    if (_landOn == id) _landOn = null;
  }

  void choose(VaultFilter filter) {
    _filter = filter;
    _oldestFirst = false;
    notifyListeners();
  }

  void search(String query) {
    if (query == _query) return;
    _query = query;
    notifyListeners();
  }

  void reviewOld() {
    _filter = VaultFilter.all;
    _query = '';
    _oldestFirst = true;
    notifyListeners();
  }

  void _reload() {
    final ids = _items.items.map((item) => item.id).toSet();
    _landOn = ids.difference(_knownIds).firstOrNull ?? _landOn;
    _knownIds = ids;
    _summaries =
        _items.active
            .map(
              (item) => ItemSummary.of(
                item,
                _today.value,
                hasOpenClaim: _claims.hasOpenClaim(item.id),
              ),
            )
            .toList()
          ..sort((a, b) {
            final rank = a.sortRank.compareTo(b.sortRank);
            return rank == 0
                ? b.item.createdAt.compareTo(a.item.createdAt)
                : rank;
          });
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _items.removeListener(_reload);
    _claims.removeListener(_reload);
    _settings.removeListener(_reload);
    _today.removeListener(_reload);
    super.dispose();
  }
}
