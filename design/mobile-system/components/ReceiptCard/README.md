# ReceiptCard

A bill in the vault, drawn as a printed receipt: the most recognisable object in PaperDrawer.

**Anatomy**
1. **Header:** "BILL" plus the store in caps, in `label`, `ink-muted`.
2. **Item name:** `card-title`, `ink`, room on the right for the stamp.
3. **Two data rows:** a key in `ink-muted` and a value in `data`; the amount in `data-strong`.
4. **Window row:**
   - Left: the window's name.
   - Right: days left, in `due-ink` if due, otherwise `ink-2`.
5. **Meter:** an 8pt bar on `paper-track`, filled `stamp-due`, `ink-2` or `stamp-expired`.
6. **Footer line:** `ink-muted`.
7. **Stamp:** rotated −12°, top right.

**Paper:** `paper` background, `space-5` padding, a 12pt zigzag torn bottom (CSS mask here; on native, a path or image mask), `shadow-paper`. Dashed `paper-dash` rules separate the sections.

**States:** DUE (≤30 days, orange), COVERED, IN CLAIM, EXPIRED (expired cards sink to the bottom of the list).

**Rules**
- **Width:** full width minus the screen margins.
- **Item name:** never truncated; it wraps to two lines.
- **Interaction:** the whole card is one button to Item detail. It lifts 2pt on press.
- **Large text:** at accessibility sizes, data rows stack and the stamp moves under the name.
