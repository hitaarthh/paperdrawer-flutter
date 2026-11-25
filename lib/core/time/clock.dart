/// The only source of "now" in the app.
///
/// Never call `DateTime.now()` outside a [Clock] implementation. Inject a
/// [Clock] instead, so tests can pin time and every layer agrees on it.
///
/// - [now] is an instant (stored as epoch milliseconds).
/// - [today] is the user's local civil date at midnight, used for deadlines.
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

/// Midnight of [instant]'s local calendar day.
DateTime civilDate(DateTime instant) =>
    DateTime(instant.year, instant.month, instant.day);
