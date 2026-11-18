# CountdownTicket

The single most urgent deadline, shown as a torn ticket at the top of the Vault and in reminders' landing screens.

**Anatomy**
- **Stub (100pt):**
  - Days left in `ticket-number` (Bricolage 800, 52).
  - The unit ("DAYS") in `label`.
  - A 2pt dashed `paper-dash` perforation on its right edge.
- **Body:**
  - Kicker in `label`, `due-ink` ("RETURN WINDOW CLOSES").
  - Item in `card-title`.
  - What to do in `callout` `ink-2`.
- **Paper:** `paper`, `radius-sm`, with two 10pt notches at the perforation, and `shadow-paper`.

**Rules**
- **When it shows:** only one ticket on screen, and only when something is due in ≤14 days.
- **Numbers:** under 1 day, show "TODAY" in the stub at `title-1` size.
- **Interaction:** tapping opens the item. Swiping dismisses it for the day.
