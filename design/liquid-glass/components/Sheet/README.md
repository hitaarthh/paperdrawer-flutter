# Sheet

A glass sheet that slides up over the current screen for short tasks: Add, Add a ledger entry, pick a date, filter.

**Provide:** a `title-2` title, the content, and one primary action at most.

- **Native first:** on iOS 26 use the system sheet with medium and large detents; at medium it is inset glass, at large it becomes opaque. The fallback: `pd-glass`, `radius-xl` 34 corners, inset 8pt from the screen edges at medium detent, full width at large with `scrim` behind and `surface-2` fill.
- **Header:** grabber, then the title left and a 36pt round glass close button right. No "Cancel" text button.
- **Choices** inside a sheet are tiles or rows on a 6% `text` wash; the selected one gets a 14% wash and a 1.5pt `text` ring. Not lime.
- **Actions:** one lime primary at the bottom (`pd-btn primary`, full width), secondary actions as `secondary` buttons in a row beneath. Keep the primary visible above the keyboard.
- **Motion:** opens with the system spring; from Scan it morphs out of the lime button.
- **Don't:** stack a sheet on a sheet, put a tab bar inside, or use a sheet for anything that needs scrolling through many items (push a screen instead).
