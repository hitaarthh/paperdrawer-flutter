import 'package:intl/intl.dart';

/// Calendar dates are stored as UTC midnight, so day maths never crosses a
/// time-zone or daylight-saving boundary. "Today" is the user's local date.
DateTime civil(DateTime date) => DateTime.utc(date.year, date.month, date.day);

DateTime today() => civil(DateTime.now());

int daysBetween(DateTime from, DateTime to) =>
    civil(to).difference(civil(from)).inDays;

DateTime addDays(DateTime date, int days) =>
    DateTime.utc(date.year, date.month, date.day + days);

/// Adds calendar months, clamping to the last day of the target month
/// (31 Jan + 1 month = 28/29 Feb).
DateTime addMonths(DateTime date, int months) {
  final first = DateTime.utc(date.year, date.month + months);
  final lastDay = DateTime.utc(first.year, first.month + 1, 0).day;
  return DateTime.utc(
    first.year,
    first.month,
    date.day > lastDay ? lastDay : date.day,
  );
}

String isoDate(DateTime date) => civil(date).toIso8601String().substring(0, 10);

DateTime? parseIsoDate(Object? value) {
  if (value is! String || value.length < 10) return null;
  final parsed = DateTime.tryParse('${value.substring(0, 10)}T00:00:00Z');
  return parsed == null ? null : civil(parsed);
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// 10.11.2026, the way a printed bill shows it.
String monoDate(DateTime d) => '${_two(d.day)}.${_two(d.month)}.${d.year}';

/// 10 Nov 2026, for sentences.
String longDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// 20 Nov
String shortDate(DateTime d) => '${d.day} ${_months[d.month - 1]}';

String _two(int n) => n.toString().padLeft(2, '0');

/// "1 DAY" / "12 DAYS"
String daysCaps(int n) => '$n ${n == 1 ? 'DAY' : 'DAYS'}';

/// "1 day" / "12 days"
String daysWord(int n) => '$n ${n == 1 ? 'day' : 'days'}';

String monthsLabel(int months) {
  if (months % 12 == 0) {
    final years = months ~/ 12;
    return '$years ${years == 1 ? 'year' : 'years'}';
  }
  return '$months ${months == 1 ? 'month' : 'months'}';
}

/// Money is stored in minor units (paise, cents) with its currency code.
/// ₹27,500 and ₹10,00,000 use Indian digit grouping.
String money(int minor, String currency) {
  final hasFraction = minor % 100 != 0;
  final format = switch (currency) {
    'INR' => NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: hasFraction ? 2 : 0,
    ),
    'USD' => NumberFormat.currency(
      locale: 'en_US',
      symbol: r'$',
      decimalDigits: hasFraction ? 2 : 0,
    ),
    _ => NumberFormat.currency(
      name: currency,
      decimalDigits: hasFraction ? 2 : 0,
    ),
  };
  return format.format(minor / 100);
}

/// "27500", "27,500.50", "₹ 2,999" → minor units. Empty → null.
/// Throws [FormatException] with a fix-it message for anything else.
int? parseMoney(String input) {
  final cleaned = input
      .replaceAll(RegExp(r'[₹,\s]'), '')
      .replaceFirst(RegExp(r'^(rs\.?|inr)', caseSensitive: false), '');
  if (cleaned.isEmpty) return null;
  final match = RegExp(r'^(\d{1,10})(?:\.(\d{1,2}))?$').firstMatch(cleaned);
  if (match == null) {
    throw const FormatException('Enter an amount like 2999 or 2,999.50.');
  }
  final whole = int.parse(match.group(1)!);
  final fraction = int.parse((match.group(2) ?? '0').padRight(2, '0'));
  return whole * 100 + fraction;
}

/// Minor units back to an editable string: 299950 → "2999.50".
String editableMoney(int minor) => minor % 100 == 0
    ? (minor ~/ 100).toString()
    : (minor / 100).toStringAsFixed(2);
