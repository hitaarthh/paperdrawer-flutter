import 'package:flutter/foundation.dart';

import 'vault_record.dart';
import 'vault_repository.dart';

class VaultController extends ChangeNotifier {
  VaultController(this._repository);

  final VaultRepository _repository;
  List<VaultRecord> _records = const [];
  VaultAppearance _themeMode = VaultAppearance.system;
  Future<void> _pending = Future.value();

  VaultAppearance get themeMode => _themeMode;
  Iterable<VaultRecord> get active =>
      _records.where((record) => !record.isArchived);
  Iterable<VaultRecord> get archive =>
      _records.where((record) => record.isArchived);

  VaultRecord? record(String id) =>
      _records.where((record) => record.id == id).firstOrNull;

  Future<void> initialize() async {
    _records = await _repository.readAll();
    _themeMode = await _repository.readTheme();
  }

  Future<void> save(VaultDraft draft, {String? id, VaultAttachment? import}) =>
      _enqueue(() async {
        await _repository.save(draft, id: id, import: import);
        _records = await _repository.readAll();
        notifyListeners();
      });

  Future<void> setArchived(String id, bool archived) => _enqueue(() async {
    await _repository.setArchived(id, archived);
    _records = await _repository.readAll();
    notifyListeners();
  });

  Future<void> setTheme(VaultAppearance mode) => _enqueue(() async {
    await _repository.setTheme(mode);
    _themeMode = mode;
    notifyListeners();
  });

  Future<void> _enqueue(Future<void> Function() operation) {
    final result = _pending.then((_) => operation());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }
}
