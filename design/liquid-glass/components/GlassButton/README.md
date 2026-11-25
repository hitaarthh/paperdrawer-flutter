# GlassButton

Round or capsule glass buttons that float at the top of a screen instead of a solid navigation bar: back, search, account, share, more, Edit.

**Provide:** an icon (round, `glass-button` 44) or a one-word label (capsule, `subhead`), and the action.

- **Native first:** on iOS 26 these are toolbar items, which the system draws as glass. The fallback uses `pd-glass` with a `text` icon at 22pt (18pt for share).
- **Placement:** 16pt from the edges, top-aligned with the status bar's bottom. Group related actions in one row with `space-2` gaps; the system merges adjacent items into one capsule.
- **Back** is a chevron alone (no previous-screen name). Edge swipe still works.
- **Scroll edge:** content scrolls under the buttons; on iOS 26 the scroll-edge effect fades it. The fallback fades `bg` 0→100% over the top 24pt.
- **One lime glass button per app:** Scan. Every other glass button is untinted.
- **Don't:** put more than three buttons on one side, use text longer than one word, or place glass buttons inside cards.
