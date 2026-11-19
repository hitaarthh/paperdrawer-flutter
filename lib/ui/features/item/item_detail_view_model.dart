import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

import '../../../data/repositories/claim_repository.dart';
import '../../../data/repositories/item_repository.dart';
import '../../../data/services/drawer_actions.dart';
import '../../../data/services/exporter.dart';
import '../../../data/services/today.dart';
import '../../../domain/item_status.dart';
import '../../../domain/models/claim.dart';
import '../../../domain/models/item.dart';

class ItemDetailViewModel extends ChangeNotifier {
  ItemDetailViewModel(
    this.id,
    this._items,
    this._claims,
    this._today,
    this._exporter,
    this._actions,
  ) {
    _items.addListener(notifyListeners);
    _claims.addListener(notifyListeners);
    _today.addListener(notifyListeners);
  }

  final String id;
  final ItemRepository _items;
  final ClaimRepository _claims;
  final Today _today;
  final Exporter _exporter;
  final DrawerActions _actions;
  bool _disposed = false;
  bool busy = false;
  String? error;

  Item? get item => _items.byId(id);
  Claim? get claim => _claims.openFor(id);
  Iterable<Claim> get itemClaims =>
      _claims.claims.where((claim) => claim.itemId == id);

  Future<Claim?> openLedger(Item item) async {
    Claim? opened;
    await _run(() async {
      opened = await _claims.openLedger(item, _today.value);
    }, 'The claim ledger couldn’t open.');
    return opened;
  }

  ItemSummary? get summary {
    final item = this.item;
    return item == null
        ? null
        : ItemSummary.of(item, _today.value, hasOpenClaim: claim != null);
  }

  Future<bool> archive(bool value) => _run(
    () => _items.setArchived(id, value),
    'The archive couldn’t be updated.',
  );

  Future<bool> delete() => _run(() async {
    await _items.delete(id);
    await _claims.load();
  }, 'This item couldn’t be deleted.');

  Future<bool> shareOriginals(Item item, Rect? origin) => _run(() async {
    final files = [
      for (final attachment in item.attachments)
        XFile(attachment.path, name: attachment.name),
    ];
    await _actions.shareFiles(files, origin: origin);
  }, 'The originals couldn’t be shared.');

  Future<bool> exportKit(Item item, Rect? origin) => _run(() async {
    final files = await _exporter.claimKit(item, claim: claim);
    await _actions.shareFiles(files, origin: origin);
  }, 'The claim kit couldn’t be shared.');

  Future<Uint8List?> thumbnail(Attachment attachment) =>
      _actions.thumbnailBytes(attachment);

  Future<bool> open(Attachment attachment) => _run(
    () => _actions.openAttachment(attachment),
    'This original couldn’t open.',
  );

  Future<bool> _run(Future<void> Function() write, String fallback) async {
    if (busy) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await write();
      return true;
    } on FormatException catch (e) {
      error = e.message;
    } on LimitReachedException catch (e) {
      error = e.message;
    } catch (_) {
      error = '$fallback Try again.';
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
    return false;
  }

  @override
  void dispose() {
    _disposed = true;
    _items.removeListener(notifyListeners);
    _claims.removeListener(notifyListeners);
    _today.removeListener(notifyListeners);
    super.dispose();
  }
}
