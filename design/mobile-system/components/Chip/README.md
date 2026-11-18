# Chip

Small selectable labels: filter chips on the dark Vault, and single-choice options on paper forms.

**Filter chips (on dark)**
- Height 36 (48 hit area), `radius-sm`, `line` border, `mono-button` label with a count at 70% opacity.
- **Selected:** a `lime` fill with `on-lime` text.
- **Layout:** one row, scrolling sideways, `space-2` apart.

**Choice on paper (claim form)**
- `ink-2` border and text.
- **Selected:** an `ink-2` fill with `paper` text.
- Single select. Wraps to more lines if needed.

**Rules**
- **Wording:** labels are nouns in UPPERCASE mono.
- **Limit:** never more than 6 filters.
- **Platform differences:** none. The same component on both (Material filter chips are restyled to this).
