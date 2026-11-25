# DeadlineAccessory

A slim glass strip above the tab bar that always shows the single most urgent deadline, so "how long do I have?" is answered on every screen.

**Provide:** the item's short name, what happens ("return closes Fri"), the count ("2 DAYS", "TODAY") and the destination (item detail or claim ledger).

- **When it shows:** only when something is due within 7 days or a claim follow-up is due today or overdue. Nothing due: no strip (never an empty or "all good" state).
- **Where:** Vault, Settings and detail screens. Not on Home, which already leads with the same deadline.
- **Look:** `glass-fill` capsule, `accessory-height` 44, `radius-pill`. An 8pt `signal` dot, the text in `subhead` `text`, the count in mono `status` style `signal-soft`. When the TabBar minimises it moves inline between the tab icon and Scan.
- **On iOS 26** use the system tab-view bottom accessory so it minimises with the bar.
- **Tap** opens the item; there is no close button. It goes away when the deadline is handled or passes.
- **Don't:** show two deadlines, use it for promotions or plan upsells, or use orange for anything that isn't time.
- **VoiceOver:** "Boat earbuds, return window closes Friday, 2 days left, button".
