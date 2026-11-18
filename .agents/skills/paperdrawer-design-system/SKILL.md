---
name: paperdrawer-design-system
description: PaperDrawer's visual language and the rules for implementing it in Flutter, covering Pd tokens, PdType typography, the paper-on-dark layout, stamps and status colours, components, motion, accessibility, and copy. Use whenever creating or changing any screen, widget, sheet, dialog, empty state, or copy in the PaperDrawer app.
---

# PaperDrawer design system

**Paper is the content, dark is the room.** The app chrome is a deep green
black. Each item is drawn as a physical paper: a receipt for a bill, an
official document for a policy, a vehicle paper, or an agreement. The paper
sits on the dark ground with a soft shadow. A lime marker is the single accent,
and orange signals urgency. The app is dark-only at launch.

Look first at the sources of truth, which win over this skill:

- `design/mobile-system/README.md` for the principles and voice,
  `platforms.md` for differences between iOS and Android, `screens.md` for
  screen recipes, `components/<Name>/` for each component's spec and
  preview, and `tokens.json` for the tokens.
- `lib/ui/core/theme/tokens.dart` (`Pd`), `type.dart` (`PdType`), and
  `app_theme.dart`.
- The UI kit in `lib/ui/core/widgets/`, listed in `ARCHITECTURE.md` under
  "UI kit". **Compose screens from the kit.** Build a new widget only when the
  design system has a component the kit lacks. Then build it in
  `lib/ui/core/widgets/` to match `components/<Name>/README.md`, and add it to
  `ARCHITECTURE.md`.

## Tokens (always `Pd.*`, never raw values in widgets)

- **Ground and chrome:** `bg`, then `surface1`, `surface2`, `surface3` for
  increasing elevation. Borders use `hairline` (subtle) and `line` (visible).
- **Text on dark:** `text`, `text2`, `textMuted`, `textSubtle`, `placeholder`.
- **Accent:** `lime`, with `limePressed` and `limeTint`. Content on lime uses
  `onLime`. Use one lime primary action per screen.
- **Signal (urgency):** `signal`, `signalSoft`, `signalTint`. Use them for
  items that are DUE (within `dueWithinDays`) and for claims that need
  escalating. `settled` marks resolved claims.
- **Paper (the content):** `paper` and `paper2` for surfaces, `paperRule`,
  `paperDash`, and `paperTrack` for rules and tracks. Ink on paper uses `ink`,
  `ink2`, `inkMuted`, and `dueInk`.
- **Stamps:** `stampDue`, `stampCovered`, `stampExpired` are the status marks
  drawn on papers.
- **Spacing** follows a 4pt scale, `s1` (4) to `s12` (48). The screen margin
  is `Pd.margin` (20). Content stays within `Pd.maxContent` (720) on tablets.
- **Radii:** `rXs` 3, `rSm` 6, `rMd` 12, `rLg` 20, `rPill`.
- **Sizes:** `tapMin` 48, `controlH` 52, `iconMd` 24 and `iconSm` 18,
  `appbarIos` 44, `tabbarIos` 49.
- **Shadows:** `shadowPaper` for papers on the ground, `shadowSheet` for
  bottom sheets. `scrim` goes behind modals.

If you need a new token, add it to `Pd` (and to `design/tokens.json` if that
exists) with a comment naming its role. Text must reach 4.5:1 contrast, and
large text or icons 3:1, against the surface they sit on, on dark and on paper
alike.

## Type (`PdType.*`)

- **Display (Bricolage):** `largeTitle` 34, `title1` 28, `title2` 22,
  `cardTitle` 20, `ticketNumber` 52 for countdown numbers.
- **Sans (Inter):** `body`, `bodyStrong`, `callout`, `footnote`, `navInline`,
  `navBack`.
- **Mono (JetBrains Mono):** `label` and `tabLabel`, for upper-case field
  labels and chips (`ItemKind.chip`, the `STORE OR SELLER`-style labels).
- Apply colour with `.copyWith(color: Pd.textMuted)`. Do not build a new
  `TextStyle` from scratch.
- Never fix the height of a box that holds text. Text must reflow at a 1.3×
  scale or larger.

## Layout and components

- Screens are a dark `bg` scaffold with a `Pd.margin` gutter, a scrollable
  body, and safe areas respected. The tab bar and app bar follow iOS metrics.
- Papers are `ReceiptPaper` (bills, with a torn zigzag bottom) and
  `DocumentPaper` (everything else, with a double rule at the top). List
  entries use `ItemCard`, which picks the right paper. Never redraw papers for
  each screen. Wrap them in a `RepaintBoundary`, and
  give their painter a correct `shouldRepaint`.
- Cover windows show as a progress track (`paperTrack`) plus a stamp. The
  countdown "ticket" appears only within `ticketWithinDays`.
- Buttons: `PdButton.primary` (lime, one per screen), `.secondary`,
  `.onPaper`, and `.text`. Scaffolds: `PdLargeTitleScaffold` for tab roots and
  `PdPushedScaffold` for pushed screens.
- Sheets, action sheets, date pickers, and confirms go through `showPdSheet`,
  `showPdActions`, `showPdDatePicker`, and `showPdConfirm`. Transient feedback
  goes through `showPdSnackbar`. Empty states use `DashedTile`.
- Empty states have a friendly headline, one line of guidance, and one clear
  action.
- Validation shows inline through `PdTextField`, and only after the field
  loses focus. Destructive, irreversible actions need
  confirmation.
- Plan limits use `LimitNotice` and `LimitFootnote` (from `baseItemWarnAt`).
  Keep it calm and informative, never a dark pattern.

## Motion

Keep motion subtle and fast: 150–250 ms with `Curves.easeOutCubic`. Papers may
lift slightly when pressed. Respect `MediaQuery.disableAnimationsOf(context)`.

## Accessibility checklist

- Make tap targets at least `Pd.tapMin`.
- Give custom-painted papers, stamps, and tickets a `Semantics` label that says
  their meaning, for example "Warranty, due in 6 days". Use
  `excludeSemantics` when children would read twice.
- Never use colour alone to show status. A stamp always carries a word (DUE,
  COVERED, EXPIRED).
- Check text scales of 1.0 and 1.3, with VoiceOver order in mind.

## Copy

Use sentence case for prose, and upper-case mono for field labels and chips.
Write short sentences in the second person. Use the typographic apostrophe (’).
Use India-first examples (Croma, Amazon, PUC centre, ₹ with `en_IN` grouping).
Name actions with verbs. Error messages say what happened and what to do next.
Ladder guidance suggests a step, and never claims PaperDrawer will act for the
user.
