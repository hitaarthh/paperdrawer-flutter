# LimitNotice

A calm notice for when the free Base plan's 25-item limit is reached: nothing is lost, here's what you can do.

**Look**
- **Block:** `signal-tint`, `radius-sm`, `space-4` padding.
- **Title:** in `label`, `signal` ("25 OF 25 ITEMS · BASE PLAN"), with a full 6pt meter.
- **Body:** in `callout`, `signal-soft`.
- **Actions:** two compact buttons. A secondary "REVIEW OLD ITEMS" and a text-style "JOIN PRO WAITLIST" in `lime`. Both have 48pt hit areas.

**Rules**
- **When it shows:** at 25/25, at the top of the Vault and in the Add sheet in place of the options.
- **Before the limit:** at 20/25, show only a `footnote` line ("5 items left on Base"). No coloured block.
- **Wording:** always say "Nothing is deleted". Never use countdowns or urgency language for the plan limit.
