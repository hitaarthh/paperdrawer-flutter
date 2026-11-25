/// The catalogue of input rules the app enforces.
///
/// One value per distinct message the user can see. The copy lives in
/// `FailureCopy` (UI layer) so it can be localised later.
enum ValidationIssue {
  /// An item needs a name so it can be found later.
  nameRequired,

  /// The name is longer than the app stores.
  nameTooLong,

  /// A bill needs its purchase date.
  purchaseDateRequired,

  /// A document needs the date it ends, renews or expires.
  endDateRequired,

  /// An end date (return window, warranty, renewal) falls before the start.
  endBeforeStart,

  /// A part warranty has a date but no part name, or the reverse.
  partWarrantyIncomplete,

  /// The amount is negative or not a number.
  amountInvalid,

  /// The currency code is not ISO 4217.
  currencyInvalid,

  /// The email address can't be right.
  emailInvalid,

  /// The password is shorter than the minimum.
  passwordTooShort,

  /// A reminder lead time outside the offered choices.
  leadTimeInvalid,

  /// A reminder time of day outside 00:00–23:59.
  timeOfDayInvalid,

  /// A stored setting has a value the app can't use.
  settingInvalid,
}
