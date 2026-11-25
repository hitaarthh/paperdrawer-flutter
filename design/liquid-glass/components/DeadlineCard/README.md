# DeadlineCard

The countdown for one upcoming date, used at the top of Home ("Coming up") and on item detail. It says the number first.

**Provide:** the day count, what ends (`RETURN WINDOW`, `POLICY RENEWAL`, `WARRANTY`), the item name, one line with the date and where, and the fraction of the window left.

- **Number:** `figure` (40) on cards, `figure-xl` (56) on item detail, tabular, with `DAYS` under it in `label`. `due-ink` when 7 days or fewer, `ink` otherwise. Today reads `TODAY` in place of the number. Counts exclude today.
- **Layout:** the number column is 64pt with a `paper-rule` hairline on its right; then eyebrow, `card-title`, and the `callout` line in `ink-muted`; the meter spans the bottom.
- **Ground:** `paper` for bills, `paper-2` for documents, as ItemCard.
- **Home** shows the two nearest; "+3 more this month" below is a `plain` button to Vault filtered to Due soon.
- **Don't:** colour the whole card orange, show more than one number per card, or add a progress percentage.
