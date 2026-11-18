---
name: paperdrawer-design-system
description: PaperDrawer's visual language and the rules for implementing it in Flutter, covering the palette, typography, layout primitives, components, motion, accessibility, and light and dark mode. Use whenever creating or changing any screen, widget, sheet, dialog, empty state, or copy in the PaperDrawer app.
---

# PaperDrawer design system

PaperDrawer should feel like a tidy paper drawer: warm paper tones, a lime
marker, receipt-edge shapes, and fine grain. The interface is quiet and
confident. Reference renders live in `design/`
(`iphone-16-vault-dark.png`, `iphone-16-settings-light.png`). Look at them
before you design a new screen.

## Tokens (always use these, never raw hex in widgets)

Read colours from `context.palette` (`lib/src/theme/drawer_theme.dart`):

| Token    | Use |
|----------|-----|
| `page`   | Scaffold, app bar, and bottom bar background |
| `panel`  | Cards, inputs, and `PaperPanel` fill |
| `text`   | Primary text |
| `muted`  | Secondary text and inactive icons |
| `line`   | Hairline borders and dividers |
| `marker` | Accent: selected tab, highlights, brand mark |
| `grain`  | Only through `DrawerSurface` |

The brand constants `drawerLime`, `drawerInk`, `drawerPaper`, and
`drawerOrange` are fixed across themes. `FilledButton` is always lime on ink.
Use `drawerOrange` sparingly, for urgency such as a deadline that is due soon.

If you need a new colour, add it to `DrawerColors` with values for both light
and dark, and confirm it reaches 4.5:1 contrast for body text on `page` and on
`panel`.

## Type

- Headings: `displayStyle(color, size)` sets Bricolage at weight 750 with tight
  tracking. Page titles are 34–38, section titles 23–26, card titles 17–20.
- Labels, metadata, and dates: `monoLabel(color, size: 11)` sets JetBrains Mono
  with wide tracking. Use upper case for small section labels such as
  `NO MATCHES`.
- Body text uses the theme default with `height: 1.4` for paragraphs, and
  `muted` for helper text.
- Never fix the height of a box that holds text. Text must reflow at a 1.3×
  scale or larger.

## Layout

- Every scrolling page is a `Scaffold` whose body is a
  `DrawerPage(children: [...])`, which gives 22pt side gutters, a 520pt
  maximum width, grain, and dismissal of the keyboard on drag.
- Group related content in a `PaperPanel` (12pt radius, `line` border). Use
  `DashedRule` for receipt-style separators inside a panel.
- Spacing comes in small odd steps, as in the existing code (3, 8, 9, 12, 16,
  19, 21, 22). Match the neighbouring code instead of inventing a new scale.
- Corner radius is 9 for controls and inputs and 12 for panels.
- Respect safe areas. The bottom bar is 62pt plus the safe area. Sheets and
  dialogs use `SafeArea`.
- Tablets and landscape are handled by the 520pt maximum width. Do not add
  breakpoints unless the task asks for an adaptive layout.

## Components and patterns

- Primary action: `FilledButton` or `FilledButton.icon`. Use one per screen.
- Secondary actions: `OutlinedButton.icon` with Material outlined icons at size
  18–19.
- Lists of records: reuse `RecordTile` (`vault_page.dart`).
- Empty states: give a friendly headline, one line of guidance, and a clear
  action. `_WelcomeTicket` and `_Starter` are the models.
- Feedback: use a floating `SnackBar` for transient results and errors. Use an
  inline message for validation, through `Form` and `validator`.
- Destructive or irreversible actions need confirmation. Archiving is
  reversible and does not.
- Custom painting: use a `CustomPainter` with a correct `shouldRepaint`,
  wrapped in a `RepaintBoundary` when it sits under content that scrolls.

## Motion

Keep motion subtle and fast: 150–250 ms with `Curves.easeOutCubic`. Use the
default page transitions. Respect `MediaQuery.disableAnimationsOf(context)`.

## Accessibility checklist

- Make tap targets at least 48×48 (the button themes already enforce this).
- Give icon-only, custom-painted, or composite controls a `Semantics(label:,
  button:, selected:)`. Use `excludeSemantics` when children would read twice,
  as `_Tab` does.
- Never use colour alone to show state. Pair it with an icon, a weight change,
  or text.
- Check both themes, and check text scales of 1.0 and 1.3.

## Copy

Use sentence case, short sentences, and a second-person voice. Use the
typographic apostrophe (’). Name actions with verbs ("Add", "Archive item",
"Retry"). Error messages say what happened and what to do next.
