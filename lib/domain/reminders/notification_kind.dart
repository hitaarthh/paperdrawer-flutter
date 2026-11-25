/// Every kind of notification PaperDrawer can send.
///
/// Lead times are in days before the deadline; `0` means "on the day".
/// The defaults below are the spec's *proposed* values ("Notification types
/// and controls"). They live only here, so confirming or changing them is a
/// one-line edit.
///
/// Family kinds (document requests, new in the family drawer, others'
/// reminders) are added with the Family plan.
enum NotificationKind {
  returnWindow(
    isDeadline: true,
    defaultOn: true,
    defaultLeadDays: [3, 0],
  ),
  warranty(
    isDeadline: true,
    defaultOn: true,
    defaultLeadDays: [30, 7],
  ),
  partWarranty(
    isDeadline: true,
    defaultOn: true,
    defaultLeadDays: [30],
  ),
  policyRenewal(
    isDeadline: true,
    defaultOn: true,
    defaultLeadDays: [30, 7, 1],
  ),
  validity(
    isDeadline: true,
    defaultOn: true,
    defaultLeadDays: [30, 7],
  ),
  agreementTerm(
    isDeadline: true,
    defaultOn: false,
    defaultLeadDays: [30],
  ),

  /// Monday morning: what's due this week.
  weeklySummary(isDeadline: false, defaultOn: true),

  /// An item saved without an end date or a photo, one day later.
  unfinishedItem(isDeadline: false, defaultOn: true),

  /// Base only: no export in 60 days.
  backupReminder(isDeadline: false, defaultOn: true),

  /// Essential and Pro: iCloud full, sync paused, sign-in expired.
  syncProblem(isDeadline: false, defaultOn: true),

  /// Product news, at most once a month.
  tips(isDeadline: false, defaultOn: false);

  const NotificationKind({
    required this.isDeadline,
    required this.defaultOn,
    this.defaultLeadDays = const [],
  });

  /// Deadline kinds always win a slot when iOS's 64-notification cap is full.
  final bool isDeadline;
  final bool defaultOn;
  final List<int> defaultLeadDays;

  /// The lead times a user may pick for a deadline kind.
  static const leadDayChoices = [0, 1, 3, 7, 14, 30];

  /// Deadline kinds in the order Settings › Notifications lists them.
  static List<NotificationKind> get deadlines =>
      values.where((kind) => kind.isDeadline).toList(growable: false);
}

/// How a notification reaches the user.
enum NotificationChannel { push, email }
