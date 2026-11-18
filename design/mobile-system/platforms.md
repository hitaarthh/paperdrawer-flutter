# iOS and Android

One brand, two platforms. Paper cards, stamps, tickets, meters, and the floating navigation dock share a design across platforms. The surrounding controls follow each platform’s conventions.

## What changes per platform

| Element | iOS | Android |
|---|---|---|
| Top-level title | Large title (`large-title` 34), collapses to an inline 17pt title on scroll | Small top app bar 64dp with `title-2` 22; a large top app bar may be used on the Vault |
| Back | Lime chevron + previous screen's name ("Vault") at top left, plus edge swipe | Arrow icon (`text`) at top left, plus system back gesture |
| Scan entry | Lime-tinted Scan or add button in the floating dock | Same |
| Primary navigation | Floating glass dock above the home indicator, with a moving pill and lime icon for the selected tab | Same, above the gesture inset |
| Tabs | Vault · Claims · Settings | Same |
| Badge on Claims | Inline count in `signal` | Same |
| Switch | iOS switch, on = `lime` track with `bg` thumb | Material 3 switch, on = `lime` track with `on-lime` thumb |
| Sheets | Native sheet with grabber; medium and large detents | Modal bottom sheet with drag handle |
| Confirmations | Snackbar-style toast at the bottom, above the tab bar (custom) | Material snackbar above the nav bar |
| Destructive confirm | Action sheet with a red system "Delete" | Dialog with `signal` text button |
| Date entry | Inline wheel or compact date picker, dark | Material date picker, tinted `lime` |
| Share | System share sheet (`square.and.arrow.up`) | System share sheet (Android share icon) |
| Overflow | Context menu from a "…" button | Three-dot overflow menu in the app bar |
| Haptics | `UIImpactFeedbackGenerator(.light)` on stamp | `HapticFeedbackConstants.CONFIRM` on stamp |

## Sizes and units

1 token px = 1pt (iOS) = 1dp (Android). Type sizes are pt and sp.

| Token | Value | Notes |
|---|---|---|
| `tap-min` | 48 | Use 48 on both; it exceeds iOS's 44pt minimum |
| `control-h` | 52 | Buttons and fields |
| `appbar-ios` / `appbar-android` | 44 / 64 | Plus status bar |
| `dock-max-width` | 440 | Dock grows in height with text size |
| `fab` | 56 | Android only |

## Type mapping and scaling

| PaperDrawer style | iOS text style it scales with | Material role it maps to |
|---|---|---|
| `large-title` 34 | Large Title | Headline Large (32) |
| `title-1` 28 | Title 1 | Headline Medium (28) |
| `title-2` 22 | Title 2 | Title Large (22) |
| `card-title` 20 | Title 3 | Title Large (22) |
| `body` 16 | Body | Body Large (16) |
| `body-strong` 16 | Headline | Title Medium (16) |
| `callout` 15 | Subheadline | Body Medium (14) |
| `footnote` 13 | Footnote | Body Small (12) |
| `label` 11 | Caption 2 | Label Small (11) |

**Scaling rules:**
- **iOS:** use the custom fonts with `UIFontMetrics(forTextStyle:)` / `.font(.custom(_, size:, relativeTo:))`.
- **Android:** sizes in `sp`.
- **Large-size test:** test at the largest accessibility size. Receipt rows switch from side by side (key left, value right) to stacked (key above value). The stamp moves below the item name. Ticket stubs grow taller, not wider.

## Safe areas and edges

- **Edge-to-edge:** draw the dark ground under the status bar and the home indicator on both platforms. Keep content inside the safe areas.
- **Clear the bottom controls:** scrollable tab content adds the measured dock inset so the last row can scroll above the floating controls.
- **Android:** use edge-to-edge with transparent system bars and light icons, and apply the window insets.

## Status bar and theme

Light content (white icons) at all times. The app is dark-only at launch, so it ignores the system light/dark setting.

The camera screen also uses a dark ground with light status icons.

## Accessibility

- **Contrast:** every text colour pair meets 4.5:1 (see each token's note). Control borders (`line`) and the focus ring (`lime`) meet 3:1.
- **Screen reader labels:**
  - **Stamps:** read as part of the card's label ("Wireless earbuds, bill, due, return window closes in 2 days"). The stamp graphic is hidden from VoiceOver and TalkBack.
  - **Meters:** expose the value as text ("2 days left of 30").
  - **Cards:** a whole card is one button with that combined label.
- **Focus:** keyboard and switch focus uses a 2px `lime` outline, 2pt offset.
- **Colour is never the only signal:** "due" always carries the word DUE and a day count, not just orange.
