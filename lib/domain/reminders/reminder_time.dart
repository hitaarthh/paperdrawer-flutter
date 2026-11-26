import 'package:flutter/foundation.dart';

import '../../core/failure/app_failure.dart';
import '../../core/failure/validation_issue.dart';
import '../../core/result/result.dart';

/// A wall-clock time of day (hours and minutes), with no date and no zone.
///
/// Deadlines are dates, so reminders fire at this local time wherever the
/// user is ("Deadlines are dates, so reminders arrive at this time wherever
/// you are"). It is a domain value: no Flutter widget `TimeOfDay`.
///
/// Stored as `HH:mm` (24-hour, zero-padded), shown as `9:00 AM`.
@immutable
final class ReminderTime implements Comparable<ReminderTime> {
  const ReminderTime._(this.hour, this.minute);

  /// Validates [hour] (0–23) and [minute] (0–59).
  ///
  /// Fails with `ValidationFailure(timeOfDayInvalid)`.
  static Result<ReminderTime> of(int hour, int minute) {
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return const Err<ReminderTime>(
        ValidationFailure(ValidationIssue.timeOfDayInvalid, field: 'timeOfDay'),
      );
    }
    return Ok(ReminderTime._(hour, minute));
  }

  /// Parses the stored form `HH:mm` (also accepts `H:mm`).
  ///
  /// Fails with `ValidationFailure(timeOfDayInvalid)`.
  static Result<ReminderTime> parse(String value) {
    final match = _pattern.firstMatch(value.trim());
    if (match == null) {
      return const Err<ReminderTime>(
        ValidationFailure(ValidationIssue.timeOfDayInvalid, field: 'timeOfDay'),
      );
    }
    return of(int.parse(match.group(1)!), int.parse(match.group(2)!));
  }

  /// The default reminder time: 9:00 AM.
  static const nineAm = ReminderTime._(9, 0);

  /// The last-day second reminder: 6:00 PM.
  static const sixPm = ReminderTime._(18, 0);

  final int hour;
  final int minute;

  /// Minutes since midnight, 0–1439.
  int get minutesOfDay => hour * 60 + minute;

  /// The stored form, `09:00`.
  String get stored =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// The 12-hour label the boards use: `9:00 AM`, `6:00 PM`, `12:30 AM`.
  String get label12h {
    final h = hour % 12 == 0 ? 12 : hour % 12;
    final suffix = hour < 12 ? 'AM' : 'PM';
    return '$h:${minute.toString().padLeft(2, '0')} $suffix';
  }

  /// [day]'s civil date (UTC midnight) at this wall-clock time, still tagged
  /// UTC. It is a *floating* local time, not an instant: the data layer turns
  /// it into the device's zone (`TZDateTime(local, y, m, d, h, min)`).
  DateTime on(DateTime day) =>
      DateTime.utc(day.year, day.month, day.day, hour, minute);

  /// The wall-clock time of [instant] (its own hour and minute fields).
  static ReminderTime ofInstant(DateTime instant) =>
      ReminderTime._(instant.hour, instant.minute);

  @override
  int compareTo(ReminderTime other) => minutesOfDay - other.minutesOfDay;

  bool isBefore(ReminderTime other) => compareTo(other) < 0;

  @override
  bool operator ==(Object other) =>
      other is ReminderTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() => 'ReminderTime($stored)';

  static final _pattern = RegExp(r'^(\d{1,2}):(\d{2})$');
}

/// [instant]'s wall clock as a floating UTC-tagged value, comparable with
/// [ReminderTime.on]. Reads the instant's own fields (local for
/// `SystemClock`), so no zone conversion happens in the domain.
DateTime wallClockOf(DateTime instant) => DateTime.utc(
  instant.year,
  instant.month,
  instant.day,
  instant.hour,
  instant.minute,
);
