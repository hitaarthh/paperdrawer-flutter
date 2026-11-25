/// The plans PaperDrawer sells, lowest first.
///
/// Each plan adds one thing the one below can't do: Essential adds sync across
/// Apple devices, Pro adds PaperDrawer cloud and the website.
///
/// Family (a shared household drawer) is still open in the spec. When it is
/// decided, add it here: every exhaustive `switch` over [Plan] will then fail
/// to compile until it handles Family, which is how we find every place that
/// needs a decision.
enum Plan {
  /// Free. No account. Everything stays on this device.
  base,

  /// Paid once. Sign in with Apple. Syncs through the user's own iCloud.
  essential,

  /// Subscription. Syncs through PaperDrawer cloud; adds the website.
  pro;

  /// True when this plan includes everything [other] includes.
  bool includes(Plan other) => index >= other.index;

  /// The highest of [plans], or [Plan.base] when empty.
  static Plan highest(Iterable<Plan> plans) => plans.fold(
    Plan.base,
    (best, plan) => plan.index > best.index ? plan : best,
  );
}

/// Where a plan keeps the vault besides this device.
enum SyncKind {
  /// Nowhere else (Base).
  none,

  /// The user's own iCloud, through CloudKit (Essential).
  iCloud,

  /// PaperDrawer cloud, through Supabase (Pro).
  paperDrawerCloud,
}

/// Ways to sign in.
enum SignInMethod { apple, email, google }
