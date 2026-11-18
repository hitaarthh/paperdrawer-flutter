# Button

Buttons for the one thing to do next (primary lime), quieter alternatives (secondary), actions printed on paper, and inline text actions.

**Variants**
- **Primary:**
  - `lime` fill, `on-lime` label in `body-strong`, height `control-h` 52, `radius-sm`.
  - Full width inside forms and sheets.
  - One per screen.
- **Pressed:** `lime-pressed`. On Android this is the ripple's base; on iOS it's the highlight.
- **Disabled:** `surface-3` fill, `text-subtle` label. Prefer explaining why it's disabled over showing a dead button.
- **Secondary on dark:**
  - Transparent with a `line` border.
  - Label in `mono-button` UPPERCASE, `text`.
  - For Export, Copy, Share.
- **On paper:**
  - Transparent with an `ink-2` border and `ink-2` label in `mono-button`.
  - Only inside paper objects (claim form, limit review).
- **Text:**
  - `lime` label in `body-strong`, no border.
  - For low-stakes alternatives ("Type it in instead", "Forgot password?").

**Rules**
- **Wording:** labels are verbs in sentence case ("Scan a bill", "Save to drawer"). Mono buttons are UPPERCASE.
- **Icons:** an icon sits left of the label, `icon-sm` 18, `space-2` gap. Only Scan uses one by default.
- **Hit area:** minimum `tap-min` 48 even when the button is drawn smaller.
- **Platform differences:** iOS shows a 0.7 opacity highlight on press; Android a ripple in `on-lime` at 12%. Same shape on both.
