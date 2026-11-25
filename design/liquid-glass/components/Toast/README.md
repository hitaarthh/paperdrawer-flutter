# Toast

A short glass confirmation that rises above the tab bar after an action, with an optional Undo. It replaces the old stamp animation.

**Provide:** one sentence in past tense with the useful fact ("Saved. First reminder on 17 Nov."), and an optional undo.

- **Look:** `glass-fill` capsule, `accessory-height` 44, `settled` check icon, `subhead` text, Undo as a small `plain` lime button.
- **Timing:** 4 seconds, 6 with Undo; stays while VoiceOver focus is on it. Light haptic (`.success`) when it appears.
- **Placement:** where the DeadlineAccessory sits; it replaces the accessory while visible.
- **Don't:** use it for errors that need action (use an inline message), stack two, or add "successfully".
