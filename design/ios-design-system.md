# PaperDrawer iOS design system (Liquid Glass)

> **Copied from the PaperDrawer Project doc on 25 Nov 2026, with two updates
> from the final design canvas ("PaperDrawer iOS — Liquid Glass screens"):**
> 1. **Claims are removed** from the app. Ignore every mention of claims,
>    claim logs, the claim ledger and the `claims` glyph below.
> 2. **Light and dark themes.** The canvas adds a light twin of every screen,
>    built from the website's light theme: cream page `#F7F3DF`, warm tiles,
>    olive `#465B16` wherever lime would be text. Paper, tickets, lime buttons
>    and the orange ticket look the same in both themes. Appearance defaults to
>    System. Camera stays dark in both. "Dark is the only theme" below is
>    superseded.
>
> Live, browsable version with tokens, fonts and component previews:
> https://claude.ai/artifact/6DeYWo9o3YmRwpEXifUi9V

This replaces the paper-decoration look (torn edges, tilted stamps, perforations) for the app.

PaperDrawer keeps the papers that have a date that costs money: bills, warranties, insurance policies, vehicle papers and agreements. This system is for the iPhone and iPad app (and the same iPad app on Apple-silicon Macs), built on iOS 26 Liquid Glass. It is quiet on purpose: a calm, sorted place, not a toy.

## The three layers

Every screen is built from three layers. Never mix them.

| Layer | What it is | Tokens | Shape |
|---|---|---|---|
| **The room** | The ground everything sits in | `bg`, `surface-1`…`surface-3`, `text`… | Flat, no shadows |
| **Paper** | Things the user owns: a bill, a policy | `paper`, `paper-2`, `ink`… | `radius-md` cards, no shadow at rest |
| **Glass** | Controls that float above: tab bar, toolbar buttons, sheets, toasts | `glass-fill`, `glass-lime`… | Capsules and `radius-xl` sheets |

- Glass is only for controls. Never put glass on a card, a list row or anything the user reads as content.
- Paper is only for content. Never make a button or a bar look like paper.
- Paper scrolls under glass. That is what makes the glass look alive, so let it happen: every scrolling screen runs under the TabBar.

## Principles

1. **One action colour.** `lime` means "do this": the Scan button, the one primary Button on a screen, switch on, links, focus. If two lime things compete on one screen, one is wrong. Selection (tabs, chips) is never lime.
2. **Orange means time.** `signal` on dark and `due-ink` on paper only mean a deadline is close. Never decoration, never errors (errors use `danger`).
3. **Say the number.** A deadline is a count ("2 days"), a meter and a date. Show the number before the explanation.
4. **Quiet over cute.** No torn edges, no tilted stamps, no perforations, no illustrations in the app. The paper metaphor lives in colour, type and the mono data rows, not in decoration.
5. **Native first.** Where iOS 26 has a control (tab bar, sheet, toolbar, switch, date picker, context menu), use the system one and tint it with these tokens. Draw your own only below iOS 26 or where the system has none.
6. **Calm, not alarming.** Limits and deadlines are stated plainly. Nothing is deleted without a confirmation.

## Content

- **Voice:** a sorted friend who knows consumer rights. Short sentences, second person, sentence case. PaperDrawer never contacts anyone for the user.
- **Casing:** sentence case everywhere. UPPERCASE only in mono `label` and `status` text, written in caps in the copy (`BILL · CROMA`, `DUE · 2 DAYS`). Separate parts with ` · `.
- **No emoji, no exclamation marks.** Confirmations are past tense with the useful fact: "Saved. First reminder on 17 Nov."
- **Money:** India-first grouping with the rupee sign: `₹1,499`, `₹4,20,000`.
- **Dates:** data rows print `10.11.2026`; sentences say `10 Nov 2026` or `Fri, 27 Nov`. Counts exclude today; today is `TODAY`.
- **Empty states** invite: "Add the last thing you bought." One line of body, one action.

## Colour

Every text pair below meets 4.5:1 (in both themes).

- **Ground:** screens on `bg`. Grouped lists and fields on `surface-1`; secondary buttons on `surface-2`; meter tracks and pressed states on `surface-3`. Separate rows with `hairline`; border controls with `line` (only on `bg` and `surface-1`).
- **Text on the room:** `text` for primary, `text-2` for secondary strong, `text-muted` for meta, `text-subtle` for the quietest lines, `placeholder` in fields.
- **Text on glass:** only `text` and `text-2`. Glass can sit over white paper, so muted greys fail there.
- **Paper:** bills on `paper`, documents on `paper-2`. Titles and figures `ink`, body and data `ink-2`, labels `ink-muted`. Hairlines on paper are `paper-rule`.
- **Status:** due `due-ink` (paper) / `signal` (room); covered `covered-ink`; ended `ended-ink`. Destructive actions `danger`.
- **Bill reading:** a value read from the photo sits on `read-highlight`; a value it couldn't read gets a dashed `line` field and a plain request ("Couldn't read · check the bill"), never red.
- **Focus:** `focus-ring` (lime) on the room and glass, `focus-ring-paper` on paper; 2pt solid, 2pt offset.

## Type

Three families, the same as paperdrawer.app: **Bricolage Grotesque** for display and figures, **Inter** for reading, **JetBrains Mono** for labels and data. All three ship as variable fonts.

- **Display** (`large-title`, `title-1`, `title-2`, `card-title`): Bricolage 700 with tight tracking (−0.015 to −0.03em). Screen titles, item names, sheet titles. Large titles collapse to `nav-title` (Inter) on scroll.
- **Figures** (`figure-xl`, `figure`, `figure-sm`): Bricolage 700–800, −0.04em, tabular numbers. Day counts and amounts only; one big figure per card.
- **Text** (`body`, `body-strong`, `callout`, `subhead`, `footnote`, `button`, `tab-label`): Inter. Body is 17pt to match iOS.
- **Mono** (`label`, `status`, `data`, `data-strong`): JetBrains Mono. `label` for UPPERCASE eyebrows and section headers (+0.08em), `data` for dates, references and amounts in data rows. Never for buttons or sentences.
- **Dynamic Type:** every style scales with the iOS text style named in its usage note, up to the largest accessibility size. At accessibility sizes data rows stack (label above value) and the DeadlineCard number moves above the title.

## Liquid Glass

- **Where glass is allowed:** TabBar, Scan button, DeadlineAccessory, GlassButton (toolbar), Sheet, Toast, the iPad sidebar, and camera controls. Nowhere else.
- **Native on iOS 26:** system tab bar, toolbar items, sheets and bottom accessory give real glass, minimise-on-scroll and morphing. Use them.
- **Fallback** (below iOS 26, or anywhere native glass isn't available): `glass-fill` (80%) under a `glass-blur` 20 / `glass-saturate` 180% backdrop, a 1pt `glass-rim` inset highlight on top, a `glass-rim-shade` ring, and `shadow-glass`. The 80% fill keeps `text` and `text-2` readable even over white paper.
- **Tinted glass** only for Scan: `glass-lime` with an `on-lime` glyph.
- **Shape:** glass is always a capsule (`radius-pill`), a circle (`glass-button`) or a sheet (`radius-xl`). Corners nest: a control inside glass uses the glass radius minus its inset.
- **Accessibility:** with Reduce Transparency, glass becomes solid `surface-2`; with Increase Contrast, add a 1pt `line` border. Both are automatic with native glass.

## Space and shape

- **Grid:** 4pt. `space-5` (20) screen margin on iPhone, `space-8` (32) on iPad; `space-4` card padding; `space-3` between cards; `space-6` between sections.
- **Radius:** paper and lists `radius-md` 14 (continuous corners), glass panels `radius-lg` 22, sheets `radius-xl` 34, everything tappable that isn't a card is `radius-pill`.
- **Sizes:** hit areas at least `tap-min` 44; buttons and fields `control-height` 50; tab bar `tab-bar-height` 62, `tab-bar-min` 48 when minimised.
- **Elevation:** the room and paper are flat. Only glass casts `shadow-glass`; sheets cast `shadow-sheet`; paper casts `shadow-paper-pressed` only while pressed or dragged.

## Layout by available width

- **Under 600 pt (iPhone, iPhone Duo closed):** single column. Large title with a mono eyebrow, content, and the TabBar with Scan floating over it. The DeadlineAccessory sits above the bar on every screen except Home.
- **600 pt and up (iPad, iPhone Duo open, Mac):** the tab bar becomes a glass sidebar (`sidebar-width` 320) with Home · Vault · Settings, the Vault filters, and "Scan or add" at the bottom. Lists use two or three columns; item detail caps at `content-max` 680. Files can be dragged in from Files.
- **Mac:** the iPad app runs on Apple-silicon Macs. Same layout as iPad, plus pointer hover (cards lift 2pt), ⌘N for Scan or add, ⌘F for search, and drop files on the window to add them. Without a camera, Scan opens Upload.

## Motion

- Use the system springs. Glass controls morph rather than fade: Scan grows into the Add sheet and into the camera controls.
- Cards scale to `pressed-scale` on press. The selection capsule slides between tabs (about 200ms).
- Saving shows a Toast with a light success haptic. No stamp animations, no confetti.
- With Reduce Motion, morphs become cross-fades and nothing scales.

## Iconography

- The `vault`, `settings` and `scan` glyphs are custom: 24×24, 2pt stroke, round caps and joins, no fill. Home uses Lucide `house`.
- Every other icon is Lucide at the same size and stroke. Use SF Symbols only where the system draws the control (the back chevron in a system bar, the share sheet).
- Icons are 22pt in bars and rows and 18pt inside buttons. Colour: `text` selected, `text-2` unselected, `on-lime` on lime.

## Logo

The mark is a lime receipt with a dark tick. Use it on `bg` or glass only, never on paper, never recoloured. The wordmark is live type: "PaperDrawer" in Bricolage Grotesque 700, −0.03em, `text`, 10pt right of the mark. The app icon is the mark centred on a full-bleed `bg` square.
