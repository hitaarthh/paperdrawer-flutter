import 'package:flutter/foundation.dart';

import '../../../data/repositories/item_repository.dart';
import '../../../domain/bill_reader.dart';
import '../../../domain/formats.dart';
import '../../../domain/models/item.dart';
import 'add_details_args.dart';

class ItemFormViewModel extends ChangeNotifier {
  ItemFormViewModel(this._items, {AddDetailsArgs? initial, this.original}) {
    final reading = initial?.reading;
    final saved = original?.draft;
    _kind = saved?.kind ?? initial?.effectiveKind ?? ItemKind.bill;
    _startsOn = saved?.startsOn ?? reading?.startsOn;
    _details[_kind] = _KindDetails(
      subtype: saved?.subtype ?? '',
      coverUntil: saved?.coverUntil ?? reading?.coverUntil,
      returnUntil: saved?.returnUntil,
      warrantyMonths: _kind == ItemKind.bill ? reading?.warrantyMonths : null,
      componentWarrantyUntil: saved?.componentWarrantyUntil,
      componentWarrantyName: saved?.componentWarrantyName ??
          (_kind == ItemKind.bill ? reading?.componentWarrantyName : null) ?? '',
      componentWarrantyMonths: _kind == ItemKind.bill ? reading?.componentWarrantyMonths : null,
    );
    _remind = saved?.remind ?? true;
    _added.addAll(initial?.files ?? const []);
    readFields = Set.unmodifiable(reading?.read ?? const <ReadField>{});
    currency = saved?.currency ?? 'INR';
    initialName = saved?.name ?? reading?.name ?? '';
    initialSource = saved?.source ?? reading?.source ?? '';
    initialReference = saved?.reference ?? reading?.reference ?? '';
    initialSerial = saved?.serialNumber ?? reading?.serialNumber ?? '';
    initialNotes = saved?.notes ?? '';
    final amount = saved?.amountMinor ?? reading?.amountMinor;
    initialAmount = amount == null ? '' : editableMoney(amount);
  }

  final ItemRepository _items;
  final Item? original;

  late final Set<ReadField> readFields;
  late final String currency;
  late final String initialName;
  late final String initialSource;
  late final String initialReference;
  late final String initialSerial;
  late final String initialNotes;
  late final String initialAmount;

  late ItemKind _kind;
  DateTime? _startsOn;
  late bool _remind;
  final _details = <ItemKind, _KindDetails>{};
  final _added = <PendingFile>[];
  final _removed = <String>{};
  bool _busy = false;
  bool _disposed = false;
  String? _error;

  _KindDetails get _active => _details[_kind]!;
  ItemKind get kind => _kind;
  String get subtype => _active.subtype;
  DateTime? get startsOn => _startsOn;
  int? get warrantyMonths => _active.warrantyMonths;
  int get reviewedFieldCount {
    final count = readFields
        .where(
          (field) =>
              field != ReadField.kind &&
              field != ReadField.coverUntil &&
              field != ReadField.warranty,
        )
        .length;
    return count +
        (readFields.contains(ReadField.coverUntil) ||
                readFields.contains(ReadField.warranty)
            ? 1
            : 0);
  }

  int? get returnDays {
    final start = startsOn;
    final end = returnUntil;
    return start == null || end == null
        ? _active.returnDays
        : daysBetween(start, end);
  }

  DateTime? get coverUntil {
    final months = warrantyMonths;
    final start = startsOn;
    return months != null && start != null
        ? addMonths(start, months)
        : _active.coverUntil;
  }

  String get componentWarrantyName => _active.componentWarrantyName;
  int? get componentWarrantyMonths => _active.componentWarrantyMonths;

  DateTime? get componentWarrantyUntil {
    final months = componentWarrantyMonths;
    final start = startsOn;
    return months != null && start != null
        ? addMonths(start, months)
        : _active.componentWarrantyUntil;
  }

  DateTime? get returnUntil {
    final days = _active.returnDays;
    final start = startsOn;
    return days != null && start != null
        ? addDays(start, days)
        : _active.returnUntil;
  }

  String get startsLabel => switch (kind) {
    ItemKind.bill => 'Purchase date',
    ItemKind.vehicle => 'Issue date',
    _ => 'Start date',
  };

  String get coverLabel => switch (kind) {
    ItemKind.bill => 'Warranty',
    ItemKind.policy => 'Renewal date',
    ItemKind.vehicle => 'Valid through',
    ItemKind.agreement => 'End date',
  };

  String get currencyPrefix => switch (currency) {
    'INR' => '₹ ',
    'USD' => r'$ ',
    _ => '$currency ',
  };

  bool get remind => _remind;
  bool get busy => _busy;
  String? get error => _error;

  Iterable<Attachment> get retained =>
      (original?.attachments ?? const <Attachment>[]).where(
        (attachment) => !_removed.contains(attachment.id),
      );

  List<PendingFile> get added => List.unmodifiable(_added);

  void setKind(ItemKind value) {
    _kind = value;
    _details.putIfAbsent(value, _KindDetails.new);
    _change();
  }

  void setSubtype(String value) {
    _active.subtype = value;
    _change();
  }

  void setStartsOn(DateTime? value) {
    _startsOn = value;
    _change();
  }

  void setCoverUntil(DateTime? value) {
    _active.warrantyMonths = null;
    _active.coverUntil = value;
    _change();
  }

  void setWarrantyMonths(int value) {
    _active.warrantyMonths = value;
    _active.coverUntil = null;
    _change();
  }

  void setComponentWarrantyUntil(DateTime? value) {
    _active.componentWarrantyUntil = value;
    _active.componentWarrantyMonths = null;
    _change();
  }

  void setComponentWarrantyName(String value) {
    _active.componentWarrantyName = value;
    _change();
  }

  void setReturnUntil(DateTime? value) {
    _active.returnDays = null;
    _active.returnUntil = value;
    _change();
  }

  void setReturnDays(int value) {
    _active.returnDays = value;
    _active.returnUntil = null;
    _change();
  }

  void setRemind(bool value) {
    _remind = value;
    _change();
  }

  void addFiles(List<PendingFile> files) {
    final paths = {..._added.map((file) => file.path)};
    _added.addAll(files.where((file) => paths.add(file.path)));
    _change();
  }

  void removeAdded(PendingFile file) {
    _added.remove(file);
    _change();
  }

  void removeOriginal(Attachment file) {
    _removed.add(file.id);
    _change();
  }

  static String? validateName(String value) =>
      value.trim().isEmpty ? 'Add a name so you can find it later.' : null;

  static String? validateAmount(String value) {
    try {
      parseMoney(value);
      return null;
    } on FormatException catch (error) {
      return error.message;
    }
  }

  Future<Item?> save({
    required String name,
    required String source,
    required String reference,
    String serialNumber = '',
    required String amount,
    required String notes,
  }) async {
    if (_busy) return null;
    _error = validateName(name) ?? validateAmount(amount) ?? _validateDates();
    if (_error != null) {
      notifyListeners();
      return null;
    }
    final draft = ItemDraft(
      kind: kind,
      name: name.trim(),
      source: source.trim(),
      subtype: subtype,
      reference: reference.trim(),
      serialNumber: kind == ItemKind.bill ? serialNumber.trim() : '',
      notes: notes.trim(),
      amountMinor: parseMoney(amount),
      currency: currency,
      startsOn: startsOn,
      returnUntil: kind == ItemKind.bill ? returnUntil : null,
      coverUntil: coverUntil,
      componentWarrantyUntil: kind == ItemKind.bill ? componentWarrantyUntil : null,
      componentWarrantyName: kind == ItemKind.bill && componentWarrantyUntil != null
          ? componentWarrantyName.trim()
          : '', 
      remind: remind,
    );
    _busy = true;
    notifyListeners();
    try {
      final existing = original;
      return existing == null
          ? await _items.create(draft, files: added)
          : await _items.update(
              existing.id,
              draft,
              addFiles: added,
              removeAttachmentIds: Set.of(_removed),
            );
    } on FormatException catch (error) {
      _error = error.message;
    } on LimitReachedException catch (error) {
      _error = error.message;
    } catch (_) {
      _error = 'Your changes couldn’t be saved. Try again.';
    } finally {
      _busy = false;
      if (!_disposed) notifyListeners();
    }
    return null;
  }

  String? _validateDates() {
    final start = startsOn;
    if ((warrantyMonths != null || componentWarrantyMonths != null) && start == null) {
      return 'Add the purchase date to work out when the warranty ends.';
    }
    if (_active.returnDays != null && start == null) {
      return 'Add the purchase date to work out when the return window closes.';
    }
    if (start == null) return null;
    final end = coverUntil;
    final returned = returnUntil;
    if (end != null && end.isBefore(start)) {
      return '$coverLabel must be on or after the ${startsLabel.toLowerCase()}.';
    }
    final componentEnd = componentWarrantyUntil;
    if (componentEnd != null && componentEnd.isBefore(start)) {
      return 'The component warranty must end on or after the purchase date.';
    }
    if (returned != null && returned.isBefore(start)) {
      return 'The return window must end on or after the purchase date.';
    }
    return null;
  }

  void _change() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class _KindDetails {
  _KindDetails({
    this.subtype = '',
    this.coverUntil,
    this.returnUntil,
    this.warrantyMonths,
    this.componentWarrantyUntil,
    this.componentWarrantyName = '',
    this.componentWarrantyMonths,
  });

  String subtype;
  DateTime? coverUntil;
  DateTime? returnUntil;
  int? warrantyMonths;
  int? returnDays;
  DateTime? componentWarrantyUntil;
  String componentWarrantyName;
  int? componentWarrantyMonths;
}
