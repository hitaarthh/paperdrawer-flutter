import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/models/shared_notification.dart';
import '../services/shared_inbox_service.dart';

class SharedInboxRepository extends ChangeNotifier {
  SharedInboxRepository(this._service);

  final SharedInboxService _service;
  String? _owner;
  int _generation = 0;
  Future<void>? _refresh;
  bool _refreshAgain = false;
  bool _failed = false;
  bool _loaded = false;
  List<SharedNotification> _items = const [];

  bool get loaded => _loaded;
  bool get failed => _failed;
  List<SharedNotification> get items => _items;
  int get unread => _items.where((item) => !item.isRead).length;

  void setOwner(String? owner) {
    _generation++;
    _owner = owner;
    _refresh = null;
    _refreshAgain = false;
    _failed = false;
    _loaded = false;
    _items = const [];
    notifyListeners();
    if (owner != null) unawaited(refresh());
  }

  Future<void> refresh() {
    final owner = _owner;
    if (owner == null) return Future.value();
    if (_refresh case final pending?) {
      _refreshAgain = true;
      return pending;
    }
    return _refresh = _load(owner, _generation);
  }

  Future<void> _load(String owner, int generation) async {
    do {
      _refreshAgain = false;
      try {
        final items = await _service.fetch(owner);
        if (generation != _generation) return;
        _items = items;
        _loaded = true;
        _failed = false;
      } catch (_) {
        if (generation != _generation) return;
        _failed = true;
      }
      notifyListeners();
    } while (generation == _generation && _refreshAgain);
    if (generation == _generation) _refresh = null;
  }

  Future<bool> open(SharedNotification notification) async {
    final owner = _owner;
    if (owner == null) return false;
    if (notification.isRead) return true;
    final generation = _generation;
    await _service.markRead(owner, notification.id);
    if (generation != _generation) return false;
    await refresh();
    return generation == _generation;
  }

  @override
  void dispose() {
    _generation++;
    _owner = null;
    super.dispose();
  }
}
