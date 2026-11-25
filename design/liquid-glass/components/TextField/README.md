# TextField

A labelled input on dark, used on "Check what we read", the item form and the ledger entry sheet.

**Provide:** a short label, the value or a realistic placeholder, and an optional hint.

- **Look:** `surface-1` fill, 1pt `line` border, `radius-md`, `control-height` 50, value in `body` `text`, placeholder in `placeholder`. Label above in `footnote` `text-muted`.
- **Focus:** 2pt `lime` border.
- **Read from the bill:** hint `FROM YOUR BILL` in `label` with a `settled` check.
- **Couldn't read:** dashed `line` border, placeholder asks for the value, hint `COULDN'T READ · CHECK THE BILL` in `text-2`. It is a request, not an error: no red, no orange.
- **Error** (wrong format): hint in `danger` with what to do ("Use a date like 10.11.2026").
- **Money** fields show ₹ and Indian grouping as the user types. Dates use the system date picker.
