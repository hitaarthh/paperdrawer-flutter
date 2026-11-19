# PaperDrawer Mobile

The design system for the PaperDrawer apps on iOS and Android. It carries the web app's look (dark ground, paper objects, rubber stamps, torn tickets) into native screens, so the phone app and paperdrawer.app feel like one product.

PaperDrawer keeps bills, insurance policies, vehicle papers and agreements, reminds people before a window closes, and walks them through a claim. Keep → Remember → Claim. The phone is where most bills get scanned, so the camera and the reminder are the two moments this system is built around.

**Read next:** [iOS and Android](platforms.md) for how each platform differs, and [Screen recipes](screens.md) for how the components assemble into the app's screens.

---

## Principles

1. **Paper is the content, dark is the room.** Everything a person owns (a bill, a policy, a ticket) is a light paper object (`paper`, `paper-2`) sitting on the dark ground (`bg`). App chrome (bars, sheets, rows) stays dark. Never put chrome on paper or paper colours on chrome.
2. **One action colour.** `lime` means "do this": Scan, Save, the selected tab, a switch that's on, the focus ring. If two lime things compete on one screen, one of them is wrong.
3. **Orange means time.** `signal` (on dark) and `stamp-due` / `due-ink` (on paper) only ever mean a deadline is close or a claim needs a push. Orange is never decoration, and never just "error".
4. **Say the number.** "2 days left", "₹27,500", "day 14". A deadline is shown as a count, a meter and a date, so nobody has to do maths.
5. **Calm, not alarming.** Limits and deadlines are stated plainly. Nothing is "expiring!!"; nothing is deleted without asking.

---

## Content fundamentals

**Voice:** a sorted friend who knows consumer rights. Short sentences, plain words, second person.

| Do | Don't |
|---|---|
| "Return window closes in 2 days" | "Hurry! Your return is expiring!" |
| "We read these from your bill. Check them before saving." | "AI-powered extraction complete" |
| "Nothing is deleted." | "Your data is safe with us 🔒" |
| "Send this to the grievance officer" | "Escalate via the appropriate channel" |

- **Casing:** sentence case for titles, buttons and rows ("Scan a bill"). UPPERCASE only in the mono `label`, `tab-label` and `mono-button` styles, and in stamps.
- **Numbers and money (India first):** `₹27,500` and `₹10,00,000` (Indian grouping). Receipt rows show dates as `10.11.2026` in mono, like a printed bill. Sentences say `10 Nov 2026`. Countdowns say `2 DAYS` / `2 days left`, never "48 hours".
- **Legal guidance:** claim steps are suggestions. Say "You can call 1915", never "We will file". PaperDrawer never contacts anyone for the user.
- **No emoji** in UI text.

---

## Visual foundations

### Colour

All colours are in one Dark theme. The app ships dark-only at launch (paper cards are the light surface), and the status bar uses light content on both platforms.

| Role | Tokens |
|---|---|
| Ground and chrome | `bg`, `surface-1` (fields, grouped rows), `surface-2` (sheets, snackbars, cards on dark), `surface-3` (tracks, disabled), `hairline`, `line` |
| Text on dark | `text`, `text-2`, `text-muted`, `text-subtle`, `placeholder` |
| Action | `lime`, `lime-pressed`, `lime-tint`, `on-lime` |
| Time and status on dark | `signal`, `signal-soft`, `signal-tint`, `settled` |
| Paper | `paper` (bills, tickets), `paper-2` (documents), `paper-rule`, `paper-dash`, `paper-track` |
| Ink on paper | `ink`, `ink-2`, `ink-muted`, `due-ink` |
| Stamps | `stamp-due`, `stamp-covered`, `stamp-expired` |

Every text pair meets 4.5:1. The two that were close on the web were fixed for mobile:
- `stamp-covered` is `#2A7449`, not `#2E7D4F` (4.5:1 on `paper-2`).
- `line` is `#66726B`, not `#2E3833` (3.5:1 for field borders).

`paper-dash` and `hairline` are decorative and never mark a control.

### Type

Three families, all free from Google Fonts:
- **Bricolage Grotesque** (`display`) for titles and item names;
- **Inter** (`sans`) for reading text and buttons;
- **JetBrains Mono** (`mono`) for labels, receipt data and stamps.

Bundle the font files in the app: Bricolage 700 and 800, Inter 400 and 600, JetBrains Mono 400, 600 and 700.

- `large-title` 34 for top-level screens, `title-1` 28 for item detail, `title-2` 22 for sheets and the Android app bar, `card-title` 20 on cards.
- `body` 16/24 is the reading size on both platforms. `callout` 15 for supporting lines, `footnote` 13 for help text.
- Mono `label` 11 (UPPERCASE, +0.1em) does the "printed receipt" work. Keep it to labels and data, never sentences.
- **Text scales.** Support Dynamic Type (iOS) and font scale (Android) up to 200%. Cards grow taller, never truncate the item name, and receipts drop the stamp below the name at the largest sizes. See [iOS and Android](platforms.md).

### Shape and depth

- **Radii:**
  - `radius-sm` 6 is the default (buttons, fields, chips, receipts, tickets).
  - Documents and stamps are sharper at `radius-xs` 3.
  - `radius-md` 12 is for the FAB and snackbars, `radius-lg` 20 for sheet tops.
  - `radius-pill` is only for switches, badges and the Android nav indicator.
- **Paper edges carry meaning:**
  - A bill has a zigzag torn bottom.
  - A document has a 6px double rule on top.
  - A ticket has two notches and a dashed perforation.
  - Don't mix them on one object.
- **Elevation is only for paper and overlays:** `shadow-paper` under paper objects, `shadow-sheet` and `shadow-fab` for overlays. Chrome is flat and separated by `hairline`.

### Spacing and layout

- 4pt grid (`space-1` to `space-12`).
- **Screen margin:** `space-5` 20 on iOS, `space-4` 16 on Android.
- The vault is a single column of cards with a `space-3` gap. On tablets and foldables it becomes a 2–3 column grid with a max content width of 720.
- Everything tappable has a 48×48 hit area (`tap-min`). Chips and small buttons may look 36–40 tall but pad their hit area.

### Iconography

24px icons with a 2px stroke, round caps and joins, and no fills. Use [Lucide](https://lucide.dev) for anything not in the Icons group: it matches the web.

The app draws custom Home, Vault, Add, Settings and scan glyphs. For the iOS back chevron and the system share sheet, use the platform's own symbols.

### Motion and haptics

- **Movement:** cards lift 2–3pt on press (a press state, not a hover state). Sheets slide up at 250ms ease-out. Respect Reduce Motion.
- **Stamps:** a stamp lands with a 120ms scale from 1.15 to 1 and a light impact haptic when an item is saved or a claim settles.
- **Haptics elsewhere:** none on ordinary taps.

---

## Components

| Group | Components |
|---|---|
| Actions | Button, ScanAction |
| Navigation | TabBar, NavBar |
| Cards | ReceiptCard, DocumentCard, CountdownTicket |
| Status | Stamp, Meter, LimitNotice |
| Inputs | TextField, Chip |
| Lists | ListRow |
| Claims | Claim ledger, entry sheet |
| Overlays | BottomSheet, Snackbar |

Each component's page lists its tokens, its iOS and Android differences, and its rules. The previews are HTML references to build natively from, whether that's SwiftUI and Jetpack Compose or React Native/Expo. In React Native, `tokens.json` maps one-to-one to a theme object. 1px here is 1pt on iOS and 1dp on Android.

## Logos and app icon

The mark is a lime receipt with a dark tick, from the web logo. The wordmark is "PaperDrawer" set in Bricolage Grotesque 700 at −0.03em, as live type: there is no wordmark image.

The Logos group has the mark, the iOS 1024 icon and the Android adaptive-icon foreground. The adaptive icon's background is `bg` `#0E1311`.
