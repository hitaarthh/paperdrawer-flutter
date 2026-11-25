/// The only source of "now" in the app.
///
/// Never call `DateTime.now()` outside a [Clock] implementation. Inject a
/// [Clock] instead, so tests can pin time and every layer agrees on it.
///
/// - [now] is an instant (stored as epoch milliseconds).
/// - [today] is the user's local calendar date as UTC midnight, used for
///   deadlines.
///   Deadlines are dates, not instants: never compare [now] with a deadline.
abstract interface class Clock {
  DateTime now();

  DateTime today();
}

/// The device clock.
final class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();

  @override
  DateTime today() => civilDate(DateTime.now());
}

/// A clock that only moves when told to. For tests.
final class FixedClock implements Clock {
  FixedClock(this._now);

  DateTime _now;

  @override
  DateTime now() => _now;

  @override
  DateTime today() => civilDate(_now);

  void set(DateTime value) => _now = value;

  void advance(Duration by) => _now = _now.add(by);
}

/// [instant]'s local calendar day, as UTC midnight.
///
/// Civil dates are stored as UTC midnight (the same convention as
/// `domain/formats.dart` `civil()`), so day arithmetic with `difference()` is
/// never off by one across a daylight-saving change.
DateTime civilDate(DateTime instant) =>
    DateTime.utc(instant.year, instant.month, instant.day);
