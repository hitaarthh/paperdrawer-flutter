# StatusLabel

A small outlined capsule in mono caps that states where an item or claim stands. It replaces the old rubber stamps.

**Provide:** one status word, and for due states the count (`DUE · 2 DAYS`, `DUE · TODAY`).

- **Look:** `status` text style, 22pt tall, `radius-pill`, 1pt outline in the same colour as the text, no fill, never rotated.
- **On paper:** DUE `due-ink`, COVERED and SETTLED `covered-ink`, IN CLAIM `ink-2`, ENDED `ended-ink`.
- **On dark:** DUE `signal`, OPEN `text`, SETTLED `settled`.
- **One per card**, top right. The word always carries the meaning; colour only repeats it.
- **Don't:** fill it, add an icon, or invent new statuses. The set is DUE, COVERED, IN CLAIM, OPEN, SETTLED, ENDED.
