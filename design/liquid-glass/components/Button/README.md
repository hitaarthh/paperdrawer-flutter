# Button

Capsule buttons. Lime marks the one thing a screen is for; everything else is quiet.

**Provide:** a verb-first label in sentence case ("Save to vault", "Add an entry"), optional leading 18pt icon, and the action.

- **primary:** `lime` fill, `on-lime` label in `button`, `control-height` 50, `radius-pill`. At most one per screen, and none on a screen where Scan is visible and is the main action. Pressed: `lime-pressed`, `pressed-scale`.
- **secondary:** `surface-2` with a `hairline` ring, `text` label. For Share, Upload, Mark settled.
- **plain:** `lime` text, no fill. For Undo, "Skip to review", "+3 more".
- **destructive:** `danger` text, no fill, always behind a confirmation action sheet.
- **sm:** `control-height-sm` 36 with `subhead` text, inside cards and toasts.
- **Focus:** 2pt `focus-ring` outline, 2pt offset.
- **Don't:** use mono labels on buttons, all caps, two primaries side by side, or disabled buttons; keep it enabled and explain on tap.
