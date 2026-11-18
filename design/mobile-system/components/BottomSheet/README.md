# BottomSheet

A sheet that rises from the bottom for short choices, chiefly "Add to your drawer" after tapping Scan.

**Look**
- **Sheet:** `surface-2`, top corners `radius-lg`, `shadow-sheet`.
- **Behind it:** a `scrim` over the screen.
- **Top:** a 36×5 grabber in `line`, the title in `title-2`, and one supporting line in `callout` `text-muted`.
- **Options:** rows at least 64 tall.
  - A 44pt icon tile: `lime` for the recommended option, `surface-3` for the others.
  - A title and a one-line description.
  - A chevron.

**Platform differences**
- **iOS:** native sheet presentation with the medium detent; swipe down to close.
- **Android:** Material modal bottom sheet with a drag handle; back gesture closes it.

**Rules**
- **Options:** 3–5, each a different path. No forms inside.
- **First option:** the recommended one (Scan with camera).
