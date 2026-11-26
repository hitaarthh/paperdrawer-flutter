/// What happens to one account's scheduled reminders while another account
/// (or the guest drawer) is open on the same phone.
///
/// Open in the spec ("When several people share one phone"). The single
/// switch is [OtherAccountReminders.current]; agents don't decide it.
enum OtherAccountReminders {
  /// (b) Keep them, re-planned with neutral text ("A Paper Drawer deadline
  /// for another account is coming up"), deadlines only. Spec leaning.
  keepNeutral,

  /// (a) Cancel them at sign-out and reschedule at the next sign-in.
  cancel;

  /// The strategy in force. One-line change when the owner decides.
  static const current = OtherAccountReminders.keepNeutral;
}
