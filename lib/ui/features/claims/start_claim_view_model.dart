import 'package:flutter/foundation.dart';

import '../../../data/repositories/claim_repository.dart';
import '../../../data/services/today.dart';
import '../../../domain/models/claim.dart';
import '../../../domain/models/item.dart';

class StartClaimViewModel extends ChangeNotifier {
  StartClaimViewModel(this.item, this._claims, this._today)
    : _type = item.kind == ItemKind.policy ? ClaimType.insurance : ClaimType.repair,
      _noticedOn = _today.value {
    _want = wants.first;
  }

  final Item item;
  final ClaimRepository _claims;
  final Today _today;

  ClaimType _type;
  late ClaimWant _want;
  DateTime _noticedOn;
  String _problem = '';
  bool _busy = false;
  bool _disposed = false;
  String? _error;

  ClaimType get type => _type;
  ClaimWant get want => _want;
  DateTime get noticedOn => _noticedOn;
  DateTime get today => _today.value;
  bool get busy => _busy;
  String? get error => _error;
  bool get canSave => !_busy && _problem.trim().isNotEmpty;
  Claim? get existing => _claims.openFor(item.id);

  List<ClaimWant> get wants => switch (_type) {
    ClaimType.repair => const [ClaimWant.repair, ClaimWant.replacement, ClaimWant.refund],
    ClaimType.refund => const [ClaimWant.refund, ClaimWant.replacement],
    ClaimType.insurance => const [ClaimWant.payout],
  };

  void selectType(ClaimType type) {
    if (_type == type || _busy) return;
    _type = type;
    _want = wants.first;
    notifyListeners();
  }

  void selectWant(ClaimWant want) {
    if (_busy) return;
    _want = want;
    notifyListeners();
  }

  void selectNoticedOn(DateTime date) {
    if (_busy) return;
    _noticedOn = date;
    notifyListeners();
  }

  void describe(String problem) {
    _problem = problem;
    _error = null;
    notifyListeners();
  }

  Future<Claim?> save(String reference) async {
    if (!canSave) return null;
    final openClaim = existing;
    if (openClaim != null) return openClaim;

    _busy = true;
    _error = null;
    notifyListeners();
    try {
      return await _claims.start(
        itemId: item.id,
        itemLabel: item.name,
        type: _type,
        want: _want,
        problem: _problem.trim(),
        reference: reference.trim(),
        noticedOn: _noticedOn,
        today: _today.value,
      );
    } on FormatException catch (error) {
      _error = error.message;
      return null;
    } catch (_) {
      _error = 'Your claim couldn’t be saved. Try again.';
      return null;
    } finally {
      _busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
