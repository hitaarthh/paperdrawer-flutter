# ClaimLadder

The escalation route for a claim, step by step, with where the user is now and what comes next.

**Anatomy**
- **Card:** `surface-2`, `radius-sm`, `space-5` padding.
- **Header:** claim type and item, in `label`.
- **Steps:** one per rung, joined by a 2pt `line` rail.
- **Dots (28pt):**
  - Done: `settled` with a check.
  - Current: `signal` with the step number.
  - Upcoming: `line` outline.
- **Current step:** a "YOU ARE HERE · DAY 14" tag in `signal` `label`.
- **Each step:** a title in `body-strong` and one line of guidance in `footnote`.

**Ladders (India)**
- **Warranty or refund:** brand or seller → grievance officer → National Consumer Helpline 1915 → consumer commission (e-Jagriti).
- **Insurance:** insurer or TPA → grievance officer → IRDAI Bima Bharosa → Insurance Ombudsman.

**Rules**
- **Guidance, not action:** steps are guidance. Buttons say "Copy message" or "Open helpline", never "File for me".
- **Links:** phone numbers and portal links open the dialer or browser.
- **Moving on:** the next step unlocks once the user marks the current one done or no reply arrives after the expected days.
