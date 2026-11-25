# ItemCard

A paper card for one thing in the vault: a bill, a policy, vehicle papers or an agreement. The whole card is one button that opens item detail.

**Provide:** kind and source (`BILL · CROMA`), status, item name, two data rows (the last is the one that matters: total, IDV, policy number), and the nearest window with a meter.

- **Ground:** bills on `paper`, documents (policy, vehicle, agreement) on `paper-2`. No torn edges, notches, tilted stamps or shadows. `radius-md` continuous corners, `space-4` padding.
- **Type:** meta in `label` `ink-muted`; name in `card-title` `ink`; data rows in `data` with `paper-rule` hairlines; the last value in `data-strong` `ink-2`. Dates `10.11.2026`, money `₹4,20,000`.
- **Status:** one StatusLabel, top right. Due states also turn the meter and its count `due-ink`.
- **Meter:** shows time remaining, so it empties toward the deadline.
- **Lists:** single column with `space-3` gaps on iPhone; two columns on iPad and Mac; sorted by nearest date.
- **Press:** scales to `pressed-scale` with `shadow-paper-pressed`; context menu offers Open, Share, Add a ledger entry, Delete.
- **VoiceOver:** one element: "Boat Airdopes 141, bill from Croma, due, return window 2 of 10 days left".
