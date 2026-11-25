# Meter

A 4pt bar that shows how much of a window is left, with the label and the exact count above it.

**Provide:** the window's name (`RETURN`, `WARRANTY`, a component like `COMPRESSOR`), the remaining and total, and whether it's due.

- **Fill = time remaining**, so it empties toward the deadline. Track `paper-track` on paper, `surface-3` on dark.
- **Fill colour:** `ink-2` on paper, `text` on dark; `due-ink` / `signal` when 7 days or fewer. The count text takes the same colour.
- **Always with the number** in `data`: "2 of 10 days left", "11 of 12 months left". Never a percentage.
- **Stack** several windows with `space-3` (14pt) between them on item detail.
- **VoiceOver** reads the count text, not the bar.
