import 'package:flutter/foundation.dart';

import '../../../data/repositories/claim_repository.dart';
import '../../../data/repositories/item_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../data/services/today.dart';
import '../../../domain/formats.dart';
import '../../../domain/item_status.dart';

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
  List<ItemSummary> _summaries = [];

  VaultFilter get filter => _filter;
  bool get oldestFirst => _oldestFirst;
  int get activeCount => _summaries.length;
  bool get atLimit => _items.atLimit;

  int count(VaultFilter filter) => _summaries.where(filter.matches).length;

  List<ItemSummary> get visible {
    final items = _summaries.where(_filter.matches).toList();
    if (_oldestFirst) {
      items.sort((a, b) => a.item.createdAt.compareTo(b.item.createdAt));
    }
    return items;
  }

  (ItemSummary, CoverWindow)? get ticket {
    final urgent = mostUrgent(_summaries);
    if (urgent == null) return null;
    final key = ticketKey(urgent.$1, urgent.$2);
    return key == _settings.ticketDismissedKey || key == _dismissing
        ? null
        : urgent;
  }

  String ticketKey(ItemSummary summary, CoverWindow window) =>
      '${isoDate(summary.today)}/${summary.item.id}/${window.type.name}/${isoDate(window.end)}';

  Future<void> dismissTicket(String key) async {
    _dismissing = key;
    notifyListeners();
    try {
      await _settings.dismissTicket(key);
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

  void reviewOld() {
    _filter = VaultFilter.all;
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
