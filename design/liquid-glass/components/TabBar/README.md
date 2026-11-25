# TabBar

The floating Liquid Glass tab bar with the Scan button beside it: Home · Vault · Settings, then one lime glass circle that opens Scan or add.

**Provide:** the selected tab, the three destinations, the Scan action, and (on screens other than Home) the DeadlineAccessory.

- **Native first.** On iOS 26 and iPadOS 26 this is the system tab bar (`UITabBarController` / SwiftUI `TabView`), with Scan as a separate glass button in the same row, the way Apple places Search. The system gives the glass, the moving selection and the minimise-on-scroll behaviour. Below iOS 26, draw the fallback recipe: `glass-fill` under a `glass-blur` / `glass-saturate` backdrop, a 1pt `glass-rim` highlight on top and a `glass-rim-shade` ring, `shadow-glass` under it.
- **Sizes:** `tab-bar-height` 62 at rest, `tab-bar-min` 48 when minimised. `space-2` between the bar and Scan. 16pt from the screen edges, 8pt above the home indicator. Max width 440 on iPhone; on iPad and Mac the bar becomes the sidebar.
- **Selection:** the selected tab sits in a `glass-selection` capsule with `text` icon and label; unselected tabs are `text-2`. Lime is not used for selection: the only lime in the bar is Scan.
- **Labels:** `tab-label`, sentence case. Icons are the custom `home`, `vault` and `settings` glyphs at 22pt.
- **Minimised:** scrolling down shrinks the bar to the selected tab's icon and moves the DeadlineAccessory inline between it and Scan. Scrolling up, or tapping the icon, restores it.
- **Scan:** `glass-lime` with an `on-lime` scan glyph. Tap opens the Add sheet; long-press opens the camera directly. On iOS 26 it morphs into the sheet.
- **Hidden** when the keyboard is up and on full-screen flows (camera, reading).
- **Don't:** add a fourth tab, put a badge count on Scan, put text inside the Scan button, or tint the bar.
- **VoiceOver:** "Home, tab, 1 of 3, selected"; Scan reads "Scan or add, button".
