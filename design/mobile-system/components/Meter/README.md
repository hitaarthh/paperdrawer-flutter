# Meter

A flat bar showing how much of a window is left: return, warranty, policy year, service interval.

**Look**
- Track 8pt tall (6pt in notices), no rounding: it reads as printed.
- Header row in mono: the window name on the left, days left on the right in bold, in the meter colour.
- Footer line with the end date.

**Colours**
- **On dark:**
  - Track: `surface-3`.
  - Fill: `signal` when due, `lime` when healthy.
  - Labels: `text-2`, footer `text-muted`.
- **On paper:**
  - Track: `paper-track`.
  - Fill: `stamp-due` when due, `ink-2` when healthy, `stamp-expired` when ended.

**Rules**
- **What the fill means:** the part that has passed ("used up"). Days left are always written as a number too.
- **Accessibility:** expose it as text ("Return window, 2 days left, closes 20 November").
