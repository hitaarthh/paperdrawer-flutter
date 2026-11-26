import 'package:flutter/foundation.dart';

import '../../core/failure/app_failure.dart';
import 'copy_dates.dart';
import 'notification_actions.dart';
import 'notification_kind.dart';
import 'notification_subject.dart';
import 'reminder_item.dart';

/// How much a notification may say.
enum CopyDetail {
  /// Item names and dates ("On the Lock Screen: Show names").
  full,

  /// "Paper Drawer has a reminder" ("Hide details").
  hidden,

  /// Another account's reminder kept on a shared phone ("keep with neutral
  /// text", see `OtherAccountReminders`).
  otherAccount,
}

/// A notification's title and body.
@immutable
final class NotificationText {
  const NotificationText(this.title, this.body);

  final String title;
  final String body;

  @override
  bool operator ==(Object other) =>
      other is NotificationText && other.title == title && other.body == body;

  @override
  int get hashCode => Object.hash(title, body);

  @override
  String toString() => 'NotificationText($title | $body)';
}

/// Every word a notification says: the only place notification copy lives.
///
/// Wording follows the boards (iOSLockScreen, iOSNotifyReturns,
/// iOSNotifActions, iOSNotifications): sentence case, typographic
/// apostrophe, no exclamation marks, day-month dates ("Fri 27 Nov").
/// Switches are exhaustive over [NotificationSubject] and
/// [NotificationKind], so a new kind or subject does not compile without
/// copy.
abstract final class NotificationCopy {
  static const brand = 'Paper Drawer';
  static const hiddenTitle = 'Paper Drawer has a reminder';
  static const hiddenBody = 'Open your drawer to see what’s due.';
  static const otherAccountBody =
      'A Paper Drawer deadline for another account is coming up.';

  static NotificationText text(NotificationSubject subject, CopyDetail detail) {
    if (detail == CopyDetail.otherAccount) return _otherAccount(subject);
    final hidden = detail == CopyDetail.hidden;
    return switch (subject) {
      final DeadlineSubject deadline =>
        hidden
            ? const NotificationText(hiddenTitle, hiddenBody)
            : _deadline(deadline),
      OnceItemSubject(:final itemName) =>
        hidden
            ? const NotificationText(hiddenTitle, hiddenBody)
            : NotificationText(itemName, 'Open your drawer to see this file.'),
      WeeklySummarySubject(:final entries) => _weekly(entries, hidden: hidden),
      UnfinishedItemSubject(:final itemName) =>
        hidden
            ? const NotificationText(
                hiddenTitle,
                'An item you saved needs a few more details.',
              )
            : NotificationText(
                'Finish adding $itemName',
                'Add its end date or a photo of the bill so Paper Drawer can '
                    'remind you in time.',
              ),
      BackupSubject(:final daysSinceExport) => _backup(daysSinceExport),
      SyncProblemSubject(:final reason) => syncProblem(reason),
      TipSubject(:final title, :final body) => NotificationText(title, body),
    };
  }

  static NotificationText _otherAccount(NotificationSubject subject) =>
      switch (subject) {
        DeadlineSubject() ||
        OnceItemSubject() ||
        WeeklySummarySubject() ||
        UnfinishedItemSubject() => const NotificationText(
          hiddenTitle,
          otherAccountBody,
        ),
        BackupSubject() ||
        SyncProblemSubject() ||
        TipSubject() => const NotificationText(
          hiddenTitle,
          'Paper Drawer has a reminder for another account on this iPhone.',
        ),
      };

  // Deadlines ----------------------------------------------------------------

  static NotificationText _deadline(DeadlineSubject s) {
    final d = s.deadline;
    final left = s.daysLeft;
    final name = s.itemName;
    final date = CopyDates.short(d.date, s.fireOn);
    if (left < 0) {
      final when = left == -1 ? 'yesterday' : 'on $date';
      return NotificationText(
        '$name: ${_noun(d)} ended $when',
        'Open the item to see what you can still do.',
      );
    }
    final when = switch (left) {
      0 => 'today',
      1 => 'tomorrow',
      _ => 'in $left days',
    };
    final lastDay = left == 0;
    return switch (d.kind) {
      NotificationKind.returnWindow => NotificationText(
        'Return window closes $when',
        lastDay
            ? '$name · last day to return. Tap to see the bill.'
            : '$name · return by $date',
      ),
      NotificationKind.warranty => NotificationText(
        '$name warranty ends $when',
        _serviceVisit(lastDay, date),
      ),
      NotificationKind.partWarranty => NotificationText(
        '$name ${_partNoun(d)} ends $when',
        _serviceVisit(lastDay, date),
      ),
      NotificationKind.policyRenewal => d.renews
          ? NotificationText('$name renews $when', _policyRenewal(d, lastDay, date))
          : NotificationText(
              '$name expires $when',
              lastDay ? 'Cover ends today.' : 'Cover ends $date.',
            ),
      NotificationKind.validity => NotificationText(
        '$name ends $when',
        lastDay ? 'Last day it’s valid. Renew it today.' : 'Renew before $date.',
      ),
      NotificationKind.agreementTerm => d.renews
          ? NotificationText(
              '$name renews $when',
              lastDay
                  ? 'Renews today.'
                  : 'Renews $date. Change or cancel it before then if you '
                        'need to.',
            )
          : NotificationText(
              '$name ends $when',
              lastDay ? 'Ends today.' : 'Ends $date. Plan what happens next.',
            ),
      NotificationKind.weeklySummary ||
      NotificationKind.unfinishedItem ||
      NotificationKind.backupReminder ||
      NotificationKind.syncProblem ||
      NotificationKind.tips => throw StateError('${d.kind} is not a deadline'),
    };
  }

  static String _serviceVisit(bool lastDay, String date) => lastDay
      ? 'Last day of cover. Book a service visit today if anything needs fixing.'
      : 'Book a service visit before $date if anything needs fixing.';

  static String _policyRenewal(ReminderDeadline d, bool lastDay, String date) {
    if (d.keepsNoClaimBonus) {
      return lastDay
          ? 'Last day to renew and keep your no-claim bonus.'
          : 'Renew by $date to keep your no-claim bonus.';
    }
    return lastDay
        ? 'Last day to renew without a break in cover.'
        : 'Renew by $date to stay covered.';
  }

  /// "compressor warranty", or "part warranty" without a part name.
  static String _partNoun(ReminderDeadline d) {
    final part = d.partName.trim();
    return part.isEmpty ? 'part warranty' : '${_lowerFirst(part)} warranty';
  }

  /// Lower-cases the first letter of a word unless it looks like an acronym
  /// ("Compressor" → "compressor", "PCB" stays "PCB").
  static String _lowerFirst(String word) {
    if (word.length > 1 && word[1].toUpperCase() == word[1] &&
        word[1].toLowerCase() != word[1]) {
      return word;
    }
    return word[0].toLowerCase() + word.substring(1);
  }

  /// The window's noun in running text ("return window", "policy").
  static String _noun(ReminderDeadline d) => switch (d.kind) {
    NotificationKind.returnWindow => 'return window',
    NotificationKind.warranty => 'warranty',
    NotificationKind.partWarranty => _partNoun(d),
    NotificationKind.policyRenewal => 'policy',
    NotificationKind.validity => 'validity',
    NotificationKind.agreementTerm => 'agreement',
    NotificationKind.weeklySummary ||
    NotificationKind.unfinishedItem ||
    NotificationKind.backupReminder ||
    NotificationKind.syncProblem ||
    NotificationKind.tips => throw StateError('${d.kind} is not a deadline'),
  };

  /// What is due, as the weekly summary names it: "return", "renewal".
  static String dueNoun(ReminderDeadline d) => switch (d.kind) {
    NotificationKind.returnWindow => 'return',
    NotificationKind.warranty => 'warranty',
    NotificationKind.partWarranty => _partNoun(d),
    NotificationKind.policyRenewal => d.renews ? 'renewal' : 'expiry',
    NotificationKind.validity => 'renewal',
    NotificationKind.agreementTerm => d.renews ? 'renewal' : 'end',
    NotificationKind.weeklySummary ||
    NotificationKind.unfinishedItem ||
    NotificationKind.backupReminder ||
    NotificationKind.syncProblem ||
    NotificationKind.tips => throw StateError('${d.kind} is not a deadline'),
  };

  // Other kinds --------------------------------------------------------------

  /// "4 things due: Wireless earbuds return, Family health policy renewal
  /// and 2 more."
  static NotificationText _weekly(
    List<DueEntry> entries, {
    required bool hidden,
  }) {
    const title = 'This week in your drawer';
    final n = entries.length;
    final things = n == 1 ? '1 thing' : '$n things';
    if (hidden) {
      return NotificationText(
        title,
        n == 1 ? '1 thing is due this week.' : '$n things are due this week.',
      );
    }
    final labels = [
      for (final e in entries) '${e.itemName} ${dueNoun(e.deadline)}',
    ];
    final list = switch (n) {
      0 => '',
      1 => labels[0],
      2 => '${labels[0]} and ${labels[1]}',
      3 => '${labels[0]}, ${labels[1]} and ${labels[2]}',
      _ => '${labels[0]}, ${labels[1]} and ${n - 2} more',
    };
    return NotificationText(
      title,
      n == 0 ? 'Nothing is due this week.' : '$things due: $list.',
    );
  }

  static NotificationText _backup(int? daysSinceExport) => NotificationText(
    'Back up your drawer',
    daysSinceExport == null
        ? 'You haven’t exported your drawer yet. Base keeps it on this iPhone '
              'only, so save a copy to Files.'
        : 'It’s been $daysSinceExport days since your last export. Base '
              'keeps your drawer on this iPhone only, so save a copy to Files.',
  );

  /// Sync problems carry no user content, so every detail level reads the
  /// same.
  static NotificationText syncProblem(SyncPauseReason reason) =>
      switch (reason) {
        SyncPauseReason.iCloudFull => const NotificationText(
          'iCloud is full',
          'New changes aren’t backed up. Your drawer is safe on this iPhone.',
        ),
        SyncPauseReason.iCloudUnavailable => const NotificationText(
          'iCloud is off',
          'Turn on iCloud to keep backing up. Your drawer is safe on this '
              'iPhone.',
        ),
        SyncPauseReason.iCloudAccountMismatch => const NotificationText(
          'iCloud is signed in to another Apple Account',
          'Sync is paused so nothing mixes. Your drawer is safe on this '
              'iPhone.',
        ),
        SyncPauseReason.signInRequired => const NotificationText(
          'Sign in again to keep syncing',
          'Your drawer is safe on this iPhone.',
        ),
        SyncPauseReason.appUpdateRequired => const NotificationText(
          'Update Paper Drawer to keep syncing',
          'Your drawer is safe on this iPhone.',
        ),
        SyncPauseReason.offline => const NotificationText(
          'Sync is waiting for a connection',
          'It carries on by itself.',
        ),
      };

  // Settings and actions -----------------------------------------------------

  /// A kind's name in Settings › Notifications.
  static String kindName(NotificationKind kind) => switch (kind) {
    NotificationKind.returnWindow => 'Return windows',
    NotificationKind.warranty => 'Warranties ending',
    NotificationKind.partWarranty => 'Part warranties',
    NotificationKind.policyRenewal => 'Policy renewals',
    NotificationKind.validity => 'Validity ending',
    NotificationKind.agreementTerm => 'Agreement terms',
    NotificationKind.weeklySummary => 'Weekly summary',
    NotificationKind.unfinishedItem => 'Unfinished items',
    NotificationKind.backupReminder => 'Back up your drawer',
    NotificationKind.syncProblem => 'Sync problems',
    NotificationKind.tips => 'Tips and new features',
  };

  /// One lead-time chip: "On the day", "1 day", "30 days".
  static String leadChip(int days) => switch (days) {
    0 => 'On the day',
    1 => '1 day',
    _ => '$days days',
  };

  /// A kind's lead times on one line, as the boards print them:
  /// "3 days, on the day", "30, 7, 1 days", "1 day", "On the day".
  static String leadSummary(List<int> leadDays) {
    final sorted = leadDays.toSet().toList()..sort((a, b) => b - a);
    final numbers = sorted.where((d) => d > 0).toList();
    final onTheDay = sorted.contains(0);
    if (numbers.isEmpty) return onTheDay ? 'On the day' : 'None';
    final unit = numbers.length == 1 && numbers.first == 1 ? 'day' : 'days';
    final days = '${numbers.join(', ')} $unit';
    return onTheDay ? '$days, on the day' : days;
  }

  /// The long-press menu's button titles (iOSNotifActions).
  static String actionTitle(NotificationAction action) => switch (action) {
    NotificationAction.markDone => 'Mark as done',
    NotificationAction.remindTomorrow => 'Remind me tomorrow',
    NotificationAction.openItem => 'Open item',
    NotificationAction.muteItem => 'Mute this item',
  };
}
