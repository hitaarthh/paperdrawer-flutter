class SharedProfile {
  const SharedProfile({
    required this.name,
    required this.leadDays,
    required this.emailReminders,
    required this.onBasePlan,
  });

  static const leadDayChoices = [30, 7, 2];

  factory SharedProfile.fromRow(Map<String, dynamic> row) => SharedProfile(
    name: (row['display_name'] as String).trim(),
    leadDays: row['reminder_lead_days'] as int,
    emailReminders: row['email_reminders'] as bool,
    onBasePlan: row['plan'] != 'pro',
  );

  final String name;
  final int leadDays;
  final bool emailReminders;
  final bool onBasePlan;
}
