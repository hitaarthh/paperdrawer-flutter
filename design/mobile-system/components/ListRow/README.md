# ListRow

Rows for Settings and other grouped lists: with a switch, a value and chevron, an action icon, or a destructive action.

**Look**
- **Row:** minimum 56 tall, `space-4` horizontal padding.
- **Title:** in `body-strong`, `text`.
- **Value:** in `callout`, `text-muted`.
- **Trailing icons and chevrons:** `text-subtle`.
- **Groups:** a `surface-1` block with `radius-sm`, rows separated by `hairline`, and a mono `label` header above the group.

**Switches**
- **iOS:** native UISwitch, on track `lime`, thumb `bg`.
- **Android:** Material 3 switch, on track `lime`, thumb `on-lime`. Off: `line` outline, `surface-3` track.

**Destructive rows:** title in `signal`, no icon. They always confirm first: an action sheet on iOS, a dialog on Android.

**Pro-only rows:** show "Pro" as the value and a disabled switch. Tapping opens the waitlist explanation; it doesn't nag.
