import 'package:flutter/foundation.dart';

import '../../../data/repositories/claim_repository.dart';
import '../../../data/services/today.dart';
import '../../../domain/item_status.dart';
import '../../../domain/models/claim.dart';

class ClaimsViewModel extends ChangeNotifier {
  ClaimsViewModel(this._repository, this._today) {
    _repository.addListener(notifyListeners);
    _today.addListener(notifyListeners);
  }

  final ClaimRepository _repository;
  final Today _today;

  bool _showSettled = false;

  bool get showSettled => _showSettled;

  List<Claim> get visible => _repository.claims
      .where((claim) => claim.isOpen != _showSettled)
      .toList(growable: false);

  int get openCount => _repository.claims.where((claim) => claim.isOpen).length;
  int get settledCount => _repository.claims.length - openCount;
  DateTime get today => _today.value;

  void filter({required bool settled}) {
    if (_showSettled == settled) return;
    _showSettled = settled;
    notifyListeners();
  }

  @override
  void dispose() {
    _repository.removeListener(notifyListeners);
    _today.removeListener(notifyListeners);
    super.dispose();
  }
}

extension ClaimStatusStamp on ClaimStatus {
  StampKind get stamp => switch (this) {
    ClaimStatus.waiting => StampKind.waiting,
    ClaimStatus.escalate => StampKind.escalate,
    ClaimStatus.settled => StampKind.settled,
  };
}
