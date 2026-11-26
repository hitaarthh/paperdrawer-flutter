/// Date words for notification copy, in the boards' style.
///
/// Hand-written (English, India-first day-month order) so the domain needs
/// no locale setup and the output is identical on every device.
abstract final class CopyDates {
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// Within this many days of the reference day, a date shows its weekday
  /// ("Fri 27 Nov"); further away it shows its year ("20 Nov 2027").
  static const weekdayWithinDays = 183;

  /// "Fri 27 Nov" near [reference], "20 Nov 2027" further away.
  static String short(DateTime date, DateTime reference) {
    final days = DateTime.utc(date.year, date.month, date.day)
        .difference(
          DateTime.utc(reference.year, reference.month, reference.day),
        )
        .inDays
        .abs();
    return days <= weekdayWithinDays ? withWeekday(date) : withYear(date);
  }

  /// "Fri 27 Nov".
  static String withWeekday(DateTime date) =>
      '${_weekdays[date.weekday - 1]} ${date.day} ${_months[date.month - 1]}';

  /// "20 Nov 2027".
  static String withYear(DateTime date) =>
      '${date.day} ${_months[date.month - 1]} ${date.year}';

  /// "Fri" (for "You’ll miss the earbuds return on Fri").
  static String weekday(DateTime date) => _weekdays[date.weekday - 1];
}
