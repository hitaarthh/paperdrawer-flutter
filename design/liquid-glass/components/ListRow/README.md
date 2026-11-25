# ListRow

Rows in an inset grouped list, used for Settings, item facts and pickers.

**Provide:** an optional 22pt icon, a title, and one trailing element: a value, a chevron, a switch, or nothing.

- **Group:** `surface-1`, `radius-md`, rows 52pt min with `space-4` side padding and `hairline` separators. Section header above in `label` `text-muted`; footer below in `footnote` `text-subtle`.
- **Row:** icon `text-2`, title `body` `text`, value `callout` `text-muted`, chevron 18pt `text-subtle`.
- **Switch:** iOS switch, on = `lime` track with `bg` thumb.
- **Destructive row:** icon and title in `danger`, no chevron, confirms with an action sheet.
- **Native first:** on iOS 26 use the system inset-grouped list and switch, tinted with these tokens.
