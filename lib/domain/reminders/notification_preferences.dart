import 'package:flutter/foundation.dart';

import '../../core/failure/app_failure.dart';
import '../../core/failure/validation_issue.dart';
import '../../core/result/result.dart';
import '../plans/plan_policy.dart';
import 'lead_days.dart';
import 'notification_kind.dart';
import 'reminder_time.dart';

/// What the Lock Screen shows for a reminder.
enum LockScreenDetail {
  /// "Wireless earbuds · return by Fri 27 Nov".
  showNames,

  /// "Paper Drawer has a reminder".
  hideDetails,
}

/// One kind's row in Settings › Notifications and its detail page.
@immutable
final class KindSetting {
  const KindSetting._({
    required this.on,
    required this.leadDays,
    required this.push,
    required this.email,
  });

  /// Validates and normalises [leadDays] (unique, furthest first).
  ///
  /// Fails with `ValidationFailure(leadTimeInvalid, field: kind.name)` when a
  /// lead time is not one of `NotificationKind.leadDayChoices`, when a
  /// deadline kind is on with no lead time, or when a kind that is not a
  /// deadline is given lead times.
  static Result<KindSetting> create(
    NotificationKind kind, {
    required bool on,
    List<int> leadDays = const [],
    bool push = true,
    bool email = true,
  }) {
    final invalid = Err<KindSetting>(
      ValidationFailure(ValidationIssue.leadTimeInvalid, field: kind.name),
    );
    if (!kind.isDeadline) {
      return leadDays.isEmpty
          ? Ok(KindSetting._(on: on, leadDays: const [], push: push, email: email))
          : invalid;
    }
    final normalised = normaliseLeadDays(leadDays);
    if (normalised == null || (on && normalised.isEmpty)) return invalid;
    return Ok(
      KindSetting._(on: on, leadDays: normalised, push: push, email: email),
    );
  }

  /// The spec's default for [kind] (`NotificationKind.defaultOn` and
  /// `defaultLeadDays`, the single switch for the open lead-time question).
  factory KindSetting.defaultFor(NotificationKind kind) => KindSetting._(
    on: kind.defaultOn,
    leadDays: kind.isDeadline
        ? normaliseLeadDays(kind.defaultLeadDays) ?? const []
        : const [],
    push: true,
    email: true,
  );

  final bool on;

  /// Days before the deadline, furthest first; `0` is "on the day". Empty for
  /// kinds that are not deadlines.
  final List<int> leadDays;

  /// "This iPhone" in the kind's WHERE section.
  final bool push;

  /// "Email" in the kind's WHERE section (Pro only; see
  /// [NotificationPreferences.channelsFor]).
  final bool email;

  bool get remindsOnTheDay => leadDays.contains(0);

  @override
  bool operator ==(Object other) =>
      other is KindSetting &&
      other.on == on &&
      listEquals(other.leadDays, leadDays) &&
      other.push == push &&
      other.email == email;

  @override
  int get hashCode => Object.hash(on, Object.hashAll(leadDays), push, email);

  @override
  String toString() =>
      'KindSetting(on: $on, lead: $leadDays, push: $push, email: $email)';
}

/// The user's choices in Settings › Notifications.
///
/// Immutable; every change goes through a validating `with…` method that
/// returns a [Result]. Defaults come from [NotificationKind] and the spec's
/// shared controls.
@immutable
final class NotificationPreferences {
  const NotificationPreferences._({
    required Map<NotificationKind, KindSetting> kinds,
    required this.timeOfDay,
    required this.lastDayRepeat,
    required this.timeSensitiveLastDay,
    required this.lockScreen,
    required this.emailCopies,
  }) : _kinds = kinds;

  factory NotificationPreferences.defaults() => NotificationPreferences._(
    kinds: {
      for (final kind in NotificationKind.values)
        kind: KindSetting.defaultFor(kind),
    },
    timeOfDay: ReminderTime.nineAm,
    lastDayRepeat: true,
    timeSensitiveLastDay: true,
    lockScreen: LockScreenDetail.showNames,
    emailCopies: defaultEmailCopies,
  );

  /// Email copies start on, like design-v1's `email_reminders` (only Pro
  /// can use them). One-line switch if the owner decides otherwise.
  static const defaultEmailCopies = true;

  /// "Keep reminding on the last day: again at 6:00 PM".
  static const lastDayRepeatTime = ReminderTime.sixPm;

  final Map<NotificationKind, KindSetting> _kinds;

  /// One time for every reminder (default 9:00 AM local).
  final ReminderTime timeOfDay;

  /// A second last-day reminder at [lastDayRepeatTime] until marked done.
  final bool lastDayRepeat;

  /// Last-day reminders use the iOS Time Sensitive level.
  final bool timeSensitiveLastDay;

  final LockScreenDetail lockScreen;

  /// The shared "Email copies" switch (Pro).
  final bool emailCopies;

  KindSetting operator [](NotificationKind kind) =>
      _kinds[kind] ?? KindSetting.defaultFor(kind);

  /// Whether [kind] is offered on [policy] and switched on.
  bool isOn(NotificationKind kind, PlanPolicy policy) =>
      policy.notificationKinds.contains(kind) && this[kind].on;

  /// The channels [kind] really uses: the user's choice, limited to what
  /// [policy] offers (`PlanPolicy.channelsFor`). Empty when the kind is off.
  Set<NotificationChannel> channelsFor(
    NotificationKind kind,
    PlanPolicy policy,
  ) {
    final setting = this[kind];
    if (!setting.on) return const {};
    final offered = policy.channelsFor(kind);
    return {
      if (setting.push && offered.contains(NotificationChannel.push))
        NotificationChannel.push,
      if (setting.email &&
          emailCopies &&
          offered.contains(NotificationChannel.email))
        NotificationChannel.email,
    };
  }

  /// Whether the phone schedules local notifications of [kind].
  bool pushes(NotificationKind kind, PlanPolicy policy) =>
      channelsFor(kind, policy).contains(NotificationChannel.push);

  /// Replaces [kind]'s setting. See [KindSetting.create] for failures.
  Result<NotificationPreferences> withKind(
    NotificationKind kind, {
    bool? on,
    List<int>? leadDays,
    bool? push,
    bool? email,
  }) {
    final current = this[kind];
    return KindSetting.create(
      kind,
      on: on ?? current.on,
      leadDays: leadDays ?? current.leadDays,
      push: push ?? current.push,
      email: email ?? current.email,
    ).map((setting) => _copy(kinds: {..._kinds, kind: setting}));
  }

  /// Changes the shared controls. Times are validated by [ReminderTime].
  NotificationPreferences withShared({
    ReminderTime? timeOfDay,
    bool? lastDayRepeat,
    bool? timeSensitiveLastDay,
    LockScreenDetail? lockScreen,
    bool? emailCopies,
  }) => _copy(
    timeOfDay: timeOfDay,
    lastDayRepeat: lastDayRepeat,
    timeSensitiveLastDay: timeSensitiveLastDay,
    lockScreen: lockScreen,
    emailCopies: emailCopies,
  );

  /// Sets the time of day from its stored or picked form.
  ///
  /// Fails with `ValidationFailure(timeOfDayInvalid)`.
  Result<NotificationPreferences> withTimeOfDay(int hour, int minute) =>
      ReminderTime.of(hour, minute).map((time) => _copy(timeOfDay: time));

  NotificationPreferences _copy({
    Map<NotificationKind, KindSetting>? kinds,
    ReminderTime? timeOfDay,
    bool? lastDayRepeat,
    bool? timeSensitiveLastDay,
    LockScreenDetail? lockScreen,
    bool? emailCopies,
  }) => NotificationPreferences._(
    kinds: Map.unmodifiable(kinds ?? _kinds),
    timeOfDay: timeOfDay ?? this.timeOfDay,
    lastDayRepeat: lastDayRepeat ?? this.lastDayRepeat,
    timeSensitiveLastDay: timeSensitiveLastDay ?? this.timeSensitiveLastDay,
    lockScreen: lockScreen ?? this.lockScreen,
    emailCopies: emailCopies ?? this.emailCopies,
  );

  @override
  bool operator ==(Object other) {
    if (other is! NotificationPreferences) return false;
    for (final kind in NotificationKind.values) {
      if (other[kind] != this[kind]) return false;
    }
    return other.timeOfDay == timeOfDay &&
        other.lastDayRepeat == lastDayRepeat &&
        other.timeSensitiveLastDay == timeSensitiveLastDay &&
        other.lockScreen == lockScreen &&
        other.emailCopies == emailCopies;
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll([for (final kind in NotificationKind.values) this[kind]]),
    timeOfDay,
    lastDayRepeat,
    timeSensitiveLastDay,
    lockScreen,
    emailCopies,
  );
}
