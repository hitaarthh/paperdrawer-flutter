# Snackbar

A brief message at the bottom after an action, with at most one action such as UNDO.

**Look**
- **Shape:** `surface-2`, 1pt `hairline` border, `radius-md`, `shadow-fab`, at least 52 tall.
- **Message:** in `callout` `text`, with an optional leading `settled` check for success.
- **Action:** in `mono-button`, `lime`.

**Behaviour**
- **Position:** above the tab bar or navigation bar, with `space-4` margins.
- **Timing:** 4 seconds, or 8 if it has an action. Swipe to dismiss.
- **Platform differences:** Android uses the Material snackbar host, restyled. iOS uses the same custom view, since iOS has no system equivalent.

**Rules**
- **Wording:** say what happened in under 40 characters ("Saved to your drawer").
- **Errors:** never put errors here that need a decision. Use a dialog.
