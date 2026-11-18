import 'package:flutter/foundation.dart';

import '../../../data/repositories/claim_repository.dart';
import '../../../data/services/today.dart';
import '../../../domain/item_status.dart';
import '../../../domain/models/claim.dart';
import 'claims_list_data.dart';

class ClaimsViewModel extends ChangeNotifier {
  ClaimsViewModel(this._repository, this._today) {
    _repository.addListener(notifyListeners);
    _today.addListener(notifyListeners);
  }

  final ClaimRepository _repository;
  final Today _today;

  ClaimsListData get list => ClaimsListData(
    _repository.claims.map(
      (claim) => ClaimListEntry.local(claim, _today.value),
    ),
  );

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
