# FilterBar

A horizontal row of capsule chips under the Vault title: All · Due soon · In claim · Covered · Ended, each with its count.

**Provide:** the filters, their counts, and the selected one.

- **Look:** 34pt capsules, `subhead` label and a mono count. Selected: `text` fill with `bg` label. Unselected: `surface-2` fill with `text-2` label.
- **Scrolls** horizontally on iPhone with the screen margin as its inset; on iPad and Mac the same filters live in the sidebar instead.
- **Counts** update live; a filter with 0 stays visible.
- **Don't:** use lime for the selected chip, or underline tabs.
