import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Rect;

import '../../../data/repositories/claim_repository.dart';
import '../../../data/repositories/item_repository.dart';
import '../../../data/services/drawer_actions.dart';
import '../../../data/services/today.dart';
import '../../../domain/claim_message.dart';
import '../../../domain/ladders.dart';
import '../../../domain/models/claim.dart';

class ClaimDetailViewModel extends ChangeNotifier {
  ClaimDetailViewModel(this.id, this._claims, this._items, this._today, this._actions) {
    _claims.addListener(notifyListeners);
    _items.addListener(notifyListeners);
    _today.addListener(notifyListeners);
  }

  final String id;
  final ClaimRepository _claims;
  final ItemRepository _items;
  final Today _today;
  final DrawerActions _actions;
  bool _busy = false;
  bool _disposed = false;
  String? _error;

  Claim? get claim => _claims.byId(id);
  DateTime get today => _today.value;
  bool get busy => _busy;
  String? get error => _error;

  ClaimMessage messageFor(Claim claim) {
    final itemId = claim.itemId;
    return draftMessage(
      claim: claim,
      item: itemId == null ? null : _items.byId(itemId),
      today: today,
    );
  }

  LadderStep currentStep(Claim claim) => ladderFor(claim.type)[claim.step];

  String? nextStepTitle(Claim claim) {
    final next = claim.step + 1;
    return next < ladderFor(claim.type).length ? stepTitle(claim.type, next) : null;
  }

  bool canAdvance(Claim claim) =>
      claim.isOpen &&
      nextStepTitle(claim) != null &&
      (claim.status(today) == ClaimStatus.escalate ||
          _hasCurrentEvent(claim, ClaimEventKind.reply));

  bool hasLoggedSent(Claim claim) => _hasCurrentEvent(claim, ClaimEventKind.sent);

  bool _hasCurrentEvent(Claim claim, ClaimEventKind kind) => claim.events
      .takeWhile((event) => event.kind != ClaimEventKind.step && event.kind != ClaimEventKind.reopened)
      .any((event) => event.kind == kind);

  Future<bool> logSent() => _perform(() => _claims.logSent(id, today));

  Future<bool> logReply(String note) =>
      _perform(() => _claims.logReply(id, today, note: note));

  Future<bool> addNote(String note) =>
      _perform(() => _claims.addNote(id, today, note));

  Future<bool> advance() async {
    final current = claim;
    if (current == null || !canAdvance(current)) return false;
    return _perform(() => _claims.advance(id, today));
  }

  Future<bool> settle(String note) =>
      _perform(() => _claims.settle(id, today, note: note));

  Future<bool> reopen() => _perform(() => _claims.reopen(id, today));

  Future<bool> delete() => _perform(() => _claims.delete(id));

  Future<bool> copy(ClaimMessage message) => _perform(
    () => _actions.copyText(message.full),
    failure: 'The message couldn’t be copied. Try again.',
  );

  Future<bool> share(ClaimMessage message, {Rect? origin}) => _perform(
    () => _actions.shareText(message.full, origin: origin),
    failure: 'The share sheet couldn’t open. Try again.',
  );

  Future<bool> openLink(Uri uri) => _perform(
    () => _actions.openLink(uri),
    failure: 'This link couldn’t open.',
  );

  Future<bool> _perform(
    Future<void> Function() operation, {
    String failure = 'Your claim couldn’t be updated. Try again.',
  }) async {
    if (_busy) return false;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await operation();
      return true;
    } on FormatException catch (error) {
      _error = error.message;
      return false;
    } catch (_) {
      _error = failure;
      return false;
    } finally {
      _busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _claims.removeListener(notifyListeners);
    _items.removeListener(notifyListeners);
    _today.removeListener(notifyListeners);
    _disposed = true;
    super.dispose();
  }
}
