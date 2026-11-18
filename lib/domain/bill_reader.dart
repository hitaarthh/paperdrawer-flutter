import 'formats.dart';
import 'models/item.dart';

enum ReadField {
  kind,
  name,
  source,
  reference,
  amount,
  startsOn,
  coverUntil,
  warranty,
}

class ScanReading {
  const ScanReading({
    this.kind,
    this.name,
    this.source,
    this.reference,
    this.amountMinor,
    this.startsOn,
    this.coverUntil,
    this.warrantyMonths,
  });

  final ItemKind? kind;
  final String? name;
  final String? source;
  final String? reference;
  final int? amountMinor;
  final DateTime? startsOn;
  final DateTime? coverUntil;
  final int? warrantyMonths;

  Set<ReadField> get read => {
    if (kind != null) ReadField.kind,
    if (name != null) ReadField.name,
    if (source != null) ReadField.source,
    if (reference != null) ReadField.reference,
    if (amountMinor != null) ReadField.amount,
    if (startsOn != null) ReadField.startsOn,
    if (coverUntil != null) ReadField.coverUntil,
    if (warrantyMonths != null) ReadField.warranty,
  };

  bool get isEmpty => read.isEmpty;
}

final _date = RegExp(
  r'\b(\d{1,2})[. /-]+(\d{1,2}|[a-z]{3,9})[. /-]+(\d{4}|\d{2})\b',
  caseSensitive: false,
);
final _startLabel = RegExp(
  r'\b(?:invoice date|bill date|issue date|issued on|start date|purchase date|date)\b',
  caseSensitive: false,
);
final _endLabel = RegExp(
  r'\b(?:expiry|expiration|valid\s*(?:till|upto|up to|until)|renewal date|expires on|period of insurance)\b',
  caseSensitive: false,
);
final _totalLabel = RegExp(
  r'^\s*(?:grand total|net amount|amount payable|total(?: amount)?)\b',
  caseSensitive: false,
);
final _rupees = RegExp(
  r'(?:₹|\bRs\.?|\bINR)\s*([\d,]+(?:\.\d{1,2})?)',
  caseSensitive: false,
);
final _warranty = RegExp(
  r'\b(\d{1,2})\s*[- ]?\s*(years?|months?)\s+warranty\b',
  caseSensitive: false,
);
final _ref = RegExp(
  r'\b(?:invoice|bill|policy|certificate)\s*(?:no\.?|number|#)\s*[:#-]?\s*([\w/-]+)|\border\s+id\s*[:#-]?\s*([\w/-]+)',
  caseSensitive: false,
);
final _vehicle = RegExp(
  r'\b(?:PUC|pollution under control|registration certificate)\b',
  caseSensitive: false,
);
final _policy = RegExp(
  r'\b(?:policy schedule|sum insured|premium|insurance)\b',
  caseSensitive: false,
);
final _bill = RegExp(r'\b(?:invoice|receipt|bill)\b', caseSensitive: false);
final _sourceLabel = RegExp(
  r'^(?:seller|sold by|store|insurer|issued by)\s*:\s*(.+)$',
  caseSensitive: false,
);
final _nameLabel = RegExp(
  r'^(?:product|item name)\s*:\s*(.+)$',
  caseSensitive: false,
);
final _nonSource = RegExp(
  r'\b(?:invoice|receipt|bill|certificate|policy|gstin|phone|date|road|street|floor|pin code)\b|[@#]|\d{4,}',
  caseSensitive: false,
);
const _months = [
  'jan',
  'feb',
  'mar',
  'apr',
  'may',
  'jun',
  'jul',
  'aug',
  'sep',
  'oct',
  'nov',
  'dec',
];

/// Suggests facts from clearly labelled receipt lines. The form keeps every
/// suggestion editable and leaves ambiguous values blank.
ScanReading readBill(List<String> lines, {required DateTime today}) {
  final clean = lines
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  final document = clean.join('\n');
  final kind = switch (document) {
    _ when _vehicle.hasMatch(document) => ItemKind.vehicle,
    _ when _policy.hasMatch(document) => ItemKind.policy,
    _ when _bill.hasMatch(document) => ItemKind.bill,
    _ => null,
  };
  final maxStart = addDays(today, 1);
  DateTime? startsOn;
  DateTime? coverUntil;
  int? amount;
  int? warrantyMonths;
  String? reference;
  String? source;
  final productNames = <String>{};

  for (var index = 0; index < clean.length; index++) {
    final line = clean[index];
    final next = index + 1 < clean.length ? clean[index + 1] : '';
    final dates = _datesIn(line).toList();
    if (_endLabel.hasMatch(line)) {
      coverUntil ??= dates.lastOrNull ?? _datesIn(next).firstOrNull;
    } else if (_startLabel.hasMatch(line)) {
      final candidate = dates.firstOrNull ?? _datesIn(next).firstOrNull;
      if (candidate != null && !candidate.isAfter(maxStart)) {
        startsOn ??= candidate;
      }
    }

    if (_totalLabel.hasMatch(line)) {
      for (final match in _rupees.allMatches(line)) {
        final candidate = parseMoney(match.group(1)!);
        if (candidate != null && (amount == null || candidate > amount)) {
          amount = candidate;
        }
      }
    }

    final warranty = _warranty.firstMatch(line);
    if (warranty != null && warrantyMonths == null) {
      final count = int.parse(warranty.group(1)!);
      if (count > 0) {
        warrantyMonths = warranty.group(2)!.toLowerCase().startsWith('year')
            ? count * 12
            : count;
      }
    }
    final ref = _ref.firstMatch(line);
    reference ??= ref?.group(1) ?? ref?.group(2);
    source ??= _sourceLabel.firstMatch(line)?.group(1);
    final product = _nameLabel.firstMatch(line)?.group(1);
    if (product != null) productNames.add(product);
  }

  if (startsOn == null && kind == ItemKind.bill) {
    final candidates = clean
        .where((line) => !_endLabel.hasMatch(line))
        .expand(_datesIn)
        .where((date) => !date.isAfter(maxStart))
        .toSet();
    if (candidates.length == 1) startsOn = candidates.single;
  }
  if (source == null && kind != null) {
    source = clean.take(4).where((line) {
      return line.length >= 3 &&
          line.length <= 60 &&
          RegExp(r'[a-z]{2}', caseSensitive: false).hasMatch(line) &&
          !_nonSource.hasMatch(line) &&
          !_totalLabel.hasMatch(line) &&
          !_rupees.hasMatch(line);
    }).firstOrNull;
  }

  // A detected field is enough to proceed as a bill even without an invoice heading.
  final foundFacts =
      startsOn != null ||
      amount != null ||
      reference != null ||
      warrantyMonths != null;
  return ScanReading(
    kind: kind ?? (foundFacts ? ItemKind.bill : null),
    name: productNames.length == 1 ? productNames.single : null,
    source: source,
    reference: reference,
    amountMinor: amount,
    startsOn: startsOn,
    coverUntil: kind == ItemKind.bill ? null : coverUntil,
    warrantyMonths: kind == null || kind == ItemKind.bill
        ? warrantyMonths
        : null,
  );
}

Iterable<DateTime> _datesIn(String line) sync* {
  for (final match in _date.allMatches(line)) {
    final day = int.parse(match.group(1)!);
    final monthText = match.group(2)!.toLowerCase();
    final month =
        int.tryParse(monthText) ??
        (_months.indexOf(monthText.substring(0, 3)) + 1);
    final yearText = match.group(3)!;
    final year = int.parse(yearText) + (yearText.length == 2 ? 2000 : 0);
    if (year < 2000 || month < 1 || month > 12 || day < 1 || day > 31) continue;
    final date = DateTime.utc(year, month, day);
    if (date.month == month) yield date;
  }
}
