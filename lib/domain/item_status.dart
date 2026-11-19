import 'formats.dart';
import 'models/item.dart';

/// Within this many days an item is DUE (orange).
const dueWithinDays = 30;

/// The countdown ticket only shows for deadlines this close.
const ticketWithinDays = 14;

/// Free Base plan cap on active (non-archived) items.
const baseItemLimit = 25;

/// Show the "N items left on Base" footnote from this many items.
const baseItemWarnAt = 20;

enum WindowType {
  returnWindow,
  warranty,
  componentWarranty,
  policyYear,
  validity,
  term,
}

/// One period that runs out: a return window, a warranty, a policy year.
class CoverWindow {
  const CoverWindow({
    required this.type,
    required this.start,
    required this.end,
    required this.renews,
    this.component = '',
  });

  final WindowType type;
  final DateTime start;

  /// Inclusive: the window is still open on [end].
  final DateTime end;

  /// Agreements that renew rather than simply end.
  final bool renews;
  final String component;

  String get _componentLabel =>
      component.isEmpty ? 'Component warranty' : '$component warranty';

  int totalDays() {
    final days = daysBetween(start, end);
    return days < 1 ? 1 : days;
  }

  /// Days left including today's 0 ("TODAY"); negative once ended.
  int daysLeft(DateTime today) => daysBetween(today, end);

  bool isEnded(DateTime today) => daysLeft(today) < 0;

  bool isDue(DateTime today) {
    final left = daysLeft(today);
    return left >= 0 && left <= dueWithinDays;
  }

  /// Share of the window that has passed, 0..1. The meter fills with this.
  double usedFraction(DateTime today) {
    final used = daysBetween(start, today) / totalDays();
    return used.clamp(0.0, 1.0);
  }

  /// Name of the meter on cards and item detail.
  String get label => switch (type) {
    WindowType.returnWindow => 'RETURN WINDOW',
    WindowType.warranty => 'WARRANTY',
    WindowType.componentWarranty => _componentLabel.toUpperCase(),
    WindowType.policyYear => 'POLICY YEAR',
    WindowType.validity => 'VALIDITY',
    WindowType.term => 'TERM',
  };

  /// The card's window row calls a bill's warranty "COVERAGE".
  String get cardLabel => type == WindowType.warranty ? 'COVERAGE' : label;

  /// Value on the right of the card's window row.
  String cardValue(DateTime today) {
    final left = daysLeft(today);
    if (left < 0) return 'ENDED';
    if (left == 0) {
      return type == WindowType.returnWindow ? 'RETURN: TODAY' : 'ENDS TODAY';
    }
    if (isDue(today)) {
      return switch (type) {
        WindowType.returnWindow => 'RETURN: ${daysCaps(left)}',
        WindowType.policyYear when renews => 'RENEWS IN ${daysCaps(left)}',
        _ when renews => 'RENEWS IN ${daysCaps(left)}',
        _ => '${daysCaps(left)} LEFT',
      };
    }
    return '${daysCaps(left)} LEFT';
  }

  /// Meter header on item detail: "2 DAYS LEFT", "ENDED".
  String meterValue(DateTime today) {
    final left = daysLeft(today);
    if (left < 0) return 'ENDED';
    if (left == 0) return 'LAST DAY';
    return '${daysCaps(left)} LEFT';
  }

  /// Meter footer: "Closes 20 Nov 2026", "Until 10 Nov 2027".
  String meterFooter(DateTime today) {
    if (isEnded(today)) return 'Ended ${longDate(end)}';
    return switch (type) {
      WindowType.returnWindow => 'Closes ${longDate(end)}',
      WindowType.policyYear => '${renews ? 'Renews' : 'Ends'} ${longDate(end)}',
      WindowType.term when renews => 'Renews ${longDate(end)}',
      WindowType.term => 'Ends ${longDate(end)}',
      _ => 'Until ${longDate(end)}',
    };
  }

  /// Countdown ticket kicker.
  String get ticketKicker => switch (type) {
    WindowType.returnWindow => 'RETURN WINDOW CLOSES',
    WindowType.warranty => 'WARRANTY ENDS',
    WindowType.componentWarranty => '$label ENDS',
    WindowType.policyYear => renews ? 'POLICY RENEWS' : 'POLICY EXPIRES',
    WindowType.validity => 'VALIDITY ENDS',
    WindowType.term => renews ? 'AGREEMENT RENEWS' : 'AGREEMENT ENDS',
  };

  /// What to do, on tickets and in reminders.
  String action() => switch (type) {
    WindowType.returnWindow => 'Return by ${shortDate(end)}',
    WindowType.warranty || WindowType.componentWarranty =>
      'Book a service visit before ${shortDate(end)}',
    WindowType.policyYear =>
      renews
          ? 'Renew before ${shortDate(end)}'
          : 'Policy expires ${shortDate(end)}',
    WindowType.validity => 'Renew before ${shortDate(end)}',
    WindowType.term =>
      renews ? 'Renew before ${shortDate(end)}' : 'Plan for ${shortDate(end)}',
  };

  /// Spoken fact for VoiceOver and reminder titles:
  /// "return window closes in 2 days".
  String fact(DateTime today) {
    final left = daysLeft(today);
    final when = left < 0
        ? 'ended on ${longDate(end)}'
        : left == 0
        ? 'today'
        : 'in ${daysWord(left)}';
    final verb = left < 0
        ? ''
        : switch (type) {
            WindowType.returnWindow => 'closes ',
            WindowType.policyYear when renews => 'renews ',
            WindowType.term when renews => 'renews ',
            _ => 'ends ',
          };
    final noun = switch (type) {
      WindowType.returnWindow => 'return window',
      WindowType.warranty => 'warranty',
      WindowType.componentWarranty => _componentLabel.toLowerCase(),
      WindowType.policyYear => 'policy',
      WindowType.validity => 'validity',
      WindowType.term => 'agreement',
    };
    return '$noun $verb$when';
  }
}

enum ItemStatus { due, covered, inClaim, expired, none }

enum StampKind {
  due,
  covered,
  active,
  inClaim,
  expired,
  waiting,
  escalate,
  settled,
}

extension StampWord on StampKind {
  String get word => switch (this) {
    StampKind.due => 'DUE',
    StampKind.covered => 'COVERED',
    StampKind.active => 'ACTIVE',
    StampKind.inClaim => 'IN CLAIM',
    StampKind.expired => 'EXPIRED',
    StampKind.waiting => 'WAITING',
    StampKind.escalate => 'ESCALATE',
    StampKind.settled => 'SETTLED',
  };
}

/// Every printed line of an item, derived once per build from its facts.
class ItemSummary {
  ItemSummary._(this.item, this.today, this.windows, this.hasOpenClaim);

  factory ItemSummary.of(
    Item item,
    DateTime today, {
    bool hasOpenClaim = false,
  }) => ItemSummary._(item, today, windowsOf(item), hasOpenClaim);

  final Item item;
  final DateTime today;
  final List<CoverWindow> windows;
  final bool hasOpenClaim;

  ItemDraft get d => item.draft;

  List<CoverWindow> get activeWindows =>
      windows.where((w) => !w.isEnded(today)).toList()
        ..sort((a, b) => a.end.compareTo(b.end));

  /// The nearest window that hasn't ended.
  CoverWindow? get next {
    final active = activeWindows;
    return active.isEmpty ? null : active.first;
  }

  /// The window the card's row shows: the next one, or the last to end.
  CoverWindow? get shown {
    final upcoming = next;
    if (upcoming != null) return upcoming;
    if (windows.isEmpty) return null;
    return (windows.toList()..sort((a, b) => b.end.compareTo(a.end))).first;
  }

  ItemStatus get status {
    if (hasOpenClaim) return ItemStatus.inClaim;
    if (windows.isEmpty) return ItemStatus.none;
    final upcoming = next;
    if (upcoming == null) return ItemStatus.expired;
    return upcoming.isDue(today) ? ItemStatus.due : ItemStatus.covered;
  }

  StampKind? get stamp => switch (status) {
    ItemStatus.due => StampKind.due,
    ItemStatus.covered =>
      item.kind == ItemKind.bill ? StampKind.covered : StampKind.active,
    ItemStatus.inClaim => StampKind.inClaim,
    ItemStatus.expired => StampKind.expired,
    ItemStatus.none => null,
  };

  /// Sort key: soonest deadline first, undated next, expired last.
  int get sortRank => switch (status) {
    ItemStatus.expired => 1 << 30,
    ItemStatus.none => 1 << 29,
    _ => next?.daysLeft(today) ?? (1 << 28),
  };

  /// Top-left of the card: BILL, POLICY SCHEDULE, PUC CERTIFICATE.
  String get headerType => switch (item.kind) {
    ItemKind.bill => 'BILL',
    ItemKind.policy => 'POLICY SCHEDULE',
    ItemKind.vehicle =>
      d.subtype.isEmpty ? 'VEHICLE PAPER' : d.subtype.toUpperCase(),
    ItemKind.agreement =>
      d.subtype.isEmpty || d.subtype == 'Other'
          ? 'AGREEMENT'
          : d.subtype.toUpperCase(),
  };

  /// Top-right of the card: the store or issuer, in caps.
  String get headerSource => d.source.toUpperCase();

  /// Kicker on item detail: "BILL · GUPTA HOME APPLIANCES".
  String get kicker =>
      d.source.isEmpty ? headerType : '$headerType · $headerSource';

  /// The two data rows (key, value, strong).
  List<(String, String, bool)> get dataRows {
    final amount = d.amountMinor == null
        ? '—'
        : money(d.amountMinor!, d.currency) +
              (item.kind == ItemKind.policy ? '/yr' : '');
    final end = d.coverUntil == null ? '—' : monoDate(d.coverUntil!);
    return switch (item.kind) {
      ItemKind.bill => [
        ('BOUGHT', d.startsOn == null ? '—' : monoDate(d.startsOn!), false),
        ('PAID', amount, true),
      ],
      ItemKind.policy => [
        (d.coverageRenews == false ? 'EXPIRES' : 'RENEWS', end, false),
        ('PREMIUM', amount, true),
      ],
      ItemKind.vehicle => [('VALID TILL', end, false), ('FEE', amount, true)],
      ItemKind.agreement => [
        (_agreementRenews ? 'RENEWS' : 'ENDS', end, false),
        (d.subtype == 'Rent agreement' ? 'DEPOSIT' : 'FEE', amount, true),
      ],
    };
  }

  bool get _agreementRenews =>
      d.coverageRenews ?? (d.subtype != 'Other' && d.subtype != 'AMC');

  /// The line under the meter on cards.
  String get footer {
    switch (item.kind) {
      case ItemKind.bill:
        final warranty = windows
            .where((w) => w.type == WindowType.warranty)
            .firstOrNull;
        final component = windows
            .where((w) => w.type == WindowType.componentWarranty)
            .firstOrNull;
        if (shown?.type == WindowType.componentWarranty ||
            (warranty == null && component != null)) {
          return component!.meterFooter(today);
        }
        if (warranty == null) return 'No warranty on record';
        if (warranty.isEnded(today)) {
          return 'Warranty ended ${longDate(warranty.end)}';
        }
        return shown?.type == WindowType.warranty
            ? 'Until ${longDate(warranty.end)}'
            : 'Warranty until ${longDate(warranty.end)}';
      case ItemKind.policy:
        return d.reference.isNotEmpty
            ? 'Policy no. ${d.reference}'
            : (d.subtype.isEmpty
                  ? 'Insurance policy'
                  : '${d.subtype} insurance');
      case ItemKind.vehicle:
        return d.source.isNotEmpty ? 'Issued by ${d.source}' : 'Vehicle papers';
      case ItemKind.agreement:
        final type = d.subtype.isEmpty ? 'Agreement' : d.subtype;
        return d.source.isNotEmpty ? '$type with ${d.source}' : type;
    }
  }

  /// One VoiceOver label for the whole card:
  /// "Wireless earbuds, bill, due, return window closes in 2 days".
  String get semanticLabel {
    final parts = <String>[
      item.name,
      item.kind.label.toLowerCase(),
      if (stamp != null) stamp!.word.toLowerCase(),
      if (shown != null) shown!.fact(today),
    ];
    return parts.join(', ');
  }
}

/// The windows an item's facts imply.
List<CoverWindow> windowsOf(Item item) {
  final d = item.draft;
  final start = d.startsOn ?? civil(item.createdAt);
  final windows = <CoverWindow>[];
  if (d.kind == ItemKind.bill) {
    if (d.returnUntil != null) {
      windows.add(
        CoverWindow(
          type: WindowType.returnWindow,
          start: start,
          end: d.returnUntil!,
          renews: false,
        ),
      );
    }
    if (d.coverUntil != null) {
      windows.add(
        CoverWindow(
          type: WindowType.warranty,
          start: start,
          end: d.coverUntil!,
          renews: false,
        ),
      );
    }
    if (d.componentWarrantyUntil case final until?) {
      windows.add(
        CoverWindow(
          type: WindowType.componentWarranty,
          start: start,
          end: until,
          renews: false,
          component: d.componentWarrantyName.trim(),
        ),
      );
    }
    return windows;
  }
  final end = d.coverUntil;
  if (end == null) return windows;
  // Without a start date, treat it as a yearly term so the meter still means
  // something.
  final docStart = d.startsOn ?? addMonths(end, -12);
  windows.add(
    CoverWindow(
      type: switch (d.kind) {
        ItemKind.policy => WindowType.policyYear,
        ItemKind.vehicle => WindowType.validity,
        _ => WindowType.term,
      },
      start: docStart.isAfter(end) ? addMonths(end, -12) : docStart,
      end: end,
      renews: switch (d.kind) {
        ItemKind.policy => d.coverageRenews ?? true,
        ItemKind.agreement =>
          d.coverageRenews ?? (d.subtype != 'Other' && d.subtype != 'AMC'),
        _ => false,
      },
    ),
  );
  return windows;
}

enum VaultFilter {
  all('ALL'),
  due('DUE'),
  covered('COVERED'),
  expired('EXPIRED'),
  undated('NO DATE');

  const VaultFilter(this.label);
  final String label;

  bool matches(ItemSummary s) => switch (this) {
    VaultFilter.all => true,
    VaultFilter.due => s.next?.isDue(s.today) ?? false,
    VaultFilter.covered => (s.next?.daysLeft(s.today) ?? 0) > dueWithinDays,
    VaultFilter.expired => s.windows.isNotEmpty && s.next == null,
    VaultFilter.undated => s.windows.isEmpty,
  };
}

/// The single most urgent deadline within [ticketWithinDays], if any.
(ItemSummary, CoverWindow)? mostUrgent(Iterable<ItemSummary> summaries) {
  (ItemSummary, CoverWindow)? best;
  for (final s in summaries) {
    final w = s.next;
    if (w == null || w.daysLeft(s.today) > ticketWithinDays) continue;
    if (best == null || w.end.isBefore(best.$2.end)) best = (s, w);
  }
  return best;
}
