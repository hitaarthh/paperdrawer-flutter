import 'package:flutter/foundation.dart';

/// What a person keeps in the drawer. Bills are receipts; the rest are
/// documents drawn as official papers.
enum ItemKind {
  bill(
    label: 'Bill',
    chip: 'BILL',
    sourceLabel: 'STORE OR SELLER',
    sourceHint: 'e.g. Croma, Amazon',
    nameLabel: 'PRODUCT',
    nameHint: 'e.g. Wireless earbuds',
    amountLabel: 'AMOUNT PAID',
    referenceLabel: 'INVOICE NO.',
  ),
  policy(
    label: 'Policy',
    chip: 'POLICY',
    sourceLabel: 'INSURER',
    sourceHint: 'e.g. Shield General Insurance',
    nameLabel: 'POLICY NAME',
    nameHint: 'e.g. Family health policy',
    amountLabel: 'PREMIUM PER YEAR',
    referenceLabel: 'POLICY NO.',
  ),
  vehicle(
    label: 'Vehicle paper',
    chip: 'VEHICLE',
    sourceLabel: 'ISSUED BY',
    sourceHint: 'e.g. Andheri PUC centre',
    nameLabel: 'NAME',
    nameHint: 'e.g. Activa PUC',
    amountLabel: 'FEE',
    referenceLabel: 'CERTIFICATE OR REG. NO.',
  ),
  agreement(
    label: 'Agreement',
    chip: 'AGREEMENT',
    sourceLabel: 'WITH',
    sourceHint: 'e.g. landlord or company name',
    nameLabel: 'NAME',
    nameHint: 'e.g. Flat rent agreement',
    amountLabel: 'DEPOSIT OR FEE',
    referenceLabel: 'REFERENCE',
  );

  const ItemKind({
    required this.label,
    required this.chip,
    required this.sourceLabel,
    required this.sourceHint,
    required this.nameLabel,
    required this.nameHint,
    required this.amountLabel,
    required this.referenceLabel,
  });

  final String label;
  final String chip;
  final String sourceLabel;
  final String sourceHint;
  final String nameLabel;
  final String nameHint;
  final String amountLabel;
  final String referenceLabel;

  bool get isDocument => this != bill;

  /// Sub-types offered on the form for documents. Bills have none.
  List<String> get subtypes => switch (this) {
    bill => const [],
    policy => const ['Health', 'Motor', 'Life', 'Home', 'Travel'],
    vehicle => const [
      'PUC certificate',
      'Registration',
      'Insurance',
      'Service record',
    ],
    agreement => const ['Rent agreement', 'AMC', 'Membership', 'Other'],
  };
}

@immutable
class Attachment {
  const Attachment({
    required this.id,
    required this.path,
    required this.name,
    required this.bytes,
  });

  final String id;

  /// Absolute path inside the app's private storage.
  final String path;
  final String name;
  final int bytes;

  bool get isPdf => name.toLowerCase().endsWith('.pdf');
}

/// The editable facts of an item. Everything a card prints (BOUGHT, RENEWS,
/// stamps, meters) is derived from these in `item_status.dart`.
@immutable
class ItemDraft {
  const ItemDraft({
    required this.kind,
    required this.name,
    this.source = '',
    this.subtype = '',
    this.reference = '',
    this.serialNumber = '',
    this.notes = '',
    this.amountMinor,
    this.currency = 'INR',
    this.startsOn,
    this.returnUntil,
    this.coverUntil,
    this.componentWarrantyUntil,
    this.componentWarrantyName = '',
    this.remind = true,
  });

  final ItemKind kind;
  final String name;

  /// Store, insurer, issuer or the other party.
  final String source;
  final String subtype;

  /// Invoice, policy or certificate number.
  final String reference;
  final String serialNumber;
  final String notes;
  final int? amountMinor;
  final String currency;

  /// Purchase date for bills, start or issue date for documents.
  final DateTime? startsOn;

  /// Last day to return a bill.
  final DateTime? returnUntil;

  /// Warranty end for bills; renews / valid till / ends for documents.
  final DateTime? coverUntil;

  /// Separate coverage for a part, such as a compressor or motor.
  final DateTime? componentWarrantyUntil;
  final String componentWarrantyName;
  final bool remind;
}

@immutable
class Item {
  const Item({
    required this.id,
    required this.draft,
    required this.createdAt,
    this.attachments = const [],
    this.archivedAt,
  });

  final String id;
  final ItemDraft draft;
  final DateTime createdAt;
  final List<Attachment> attachments;
  final DateTime? archivedAt;

  ItemKind get kind => draft.kind;
  String get name => draft.name;
  bool get isArchived => archivedAt != null;
}

/// A file picked or captured but not yet copied into the drawer.
@immutable
class PendingFile {
  const PendingFile({required this.path, required this.name});

  final String path;
  final String name;

  bool get isPdf => name.toLowerCase().endsWith('.pdf');
}
