import 'package:flutter/foundation.dart';

import '../../../data/repositories/item_repository.dart';
import '../../../data/services/today.dart';
import '../../../domain/item_status.dart';

class VaultViewModel extends ChangeNotifier {
  VaultViewModel(this._items, this._today)
    : _knownIds = _items.items.map((item) => item.id).toSet() {
    _items.addListener(_reload);
    _today.addListener(_reload);
    _reload();
  }

  final ItemRepository _items;
  final Today _today;
  Set<String> _knownIds;
  String? _landOn;
  String? _justAddedId;
  bool _oldestFirst = false;
  VaultFilter _filter = VaultFilter.all;
  String _query = '';
  List<ItemSummary> _summaries = [];

  VaultFilter get filter => _filter;
  bool get oldestFirst => _oldestFirst;
  String get query => _query;
  int get activeCount => _summaries.length;
  bool get atLimit => _items.atLimit;
  ItemSummary? get justAdded => _summaries
      .where((summary) => summary.item.id == _justAddedId)
      .firstOrNull;

  /// Tab counts follow the search, so they always match the list.
  int count(VaultFilter filter) => _searched.where(filter.matches).length;

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

  bool shouldLand(String id) => _landOn == id;

  void landed(String id) {
    if (_landOn == id) _landOn = null;
  }

  void showRecent(String id) {
    if (!_summaries.any((summary) => summary.item.id == id)) return;
    _filter = VaultFilter.all;
    _oldestFirst = false;
    if (_justAddedId != id) _landOn = id;
    _justAddedId = id;
    notifyListeners();
  }

  void choose(VaultFilter filter) {
    _filter = filter;
    _oldestFirst = false;
    _justAddedId = null;
    notifyListeners();
  }

  void search(String query) {
    if (query == _query) return;
    _query = query;
    _justAddedId = null;
    notifyListeners();
  }

  void reviewOld() {
    _filter = VaultFilter.all;
    _query = '';
    _oldestFirst = true;
    _justAddedId = null;
    notifyListeners();
  }

  void _reload() {
    final ids = _items.items.map((item) => item.id).toSet();
    if (ids.difference(_knownIds).firstOrNull case final added?) {
      _landOn = added;
      _justAddedId = added;
    }
    if (!ids.contains(_justAddedId)) _justAddedId = null;
    _knownIds = ids;
    _summaries =
        _items.active
            .map((item) => ItemSummary.of(item, _today.value))
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
    _items.removeListener(_reload);
    _today.removeListener(_reload);
    super.dispose();
  }
}
