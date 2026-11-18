# Stamp

Rubber-stamp status labels: DUE, COVERED, ACTIVE, IN CLAIM, EXPIRED on paper, and WAITING, ESCALATE, SETTLED for claims on dark.

**Look**
- 2pt border and text in the same colour.
- `label` type at +0.12em, `radius-xs`.
- Rotated −6° to −12° on paper. Upright (0°) on dark lists, where it reads as a status tag.

**Colours**

| Stamp | On paper | On dark |
|---|---|---|
| DUE | `stamp-due` | — |
| COVERED / ACTIVE | `stamp-covered` | — |
| IN CLAIM | `ink` | — |
| EXPIRED | `stamp-expired` | — |
| WAITING | — | `text` |
| ESCALATE | — | `signal` |
| SETTLED | — | `settled` |

**Rules**
- **One stamp per object.** Never use a stamp as a button.
- **Animation:** when a status changes, the stamp lands (scale 1.15 → 1, 120ms) with a light haptic.
- **Screen readers:** the stamp graphic is hidden; its word is part of the card's label.
