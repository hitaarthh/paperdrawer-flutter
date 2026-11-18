# TextField

Single-line inputs for item details, sign-in and claim notes, with a tag for values PaperDrawer read from a scan.

**Look**
- **Label:** above the field, in `label`, `text-muted`.
- **Field:**
  - `control-h` 52, `radius-sm`, `surface-1` fill.
  - 1pt `line` border, `body` text, `placeholder` hint.
- **Focus:** a 2pt `lime` border (1pt border plus a 1pt ring).
- **Error:** `signal` border, and help text in `signal` below, saying how to fix it.
- **Read from bill:**
  - A `lime` "READ FROM BILL" tag on the right of the label.
  - Help text: "Check it against your bill before saving."

**Platform differences**
- **iOS:** clear button while editing.
- **Android:** no floating labels. The label stays above the field so both platforms match.
- **Keyboards:** decimal pad for amounts, email for email; dates open the native picker.

**Rules**
- **Placeholders:** examples, not labels.
- **Errors:** never shown on first focus, only after the user leaves the field.
