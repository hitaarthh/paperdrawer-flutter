# NavBar

The top of every screen: the iOS navigation bar (with large title on top-level screens) or the Android top app bar.

**iOS**
- **Top-level screens:** `large-title` 34 in `display`, collapsing to a 17pt semibold inline title on scroll.
- **Pushed screens:**
  - A lime chevron plus the previous title ("Vault") on the left.
  - An optional mono `label` kicker above the title (e.g. "BILL · GUPTA HOME APPLIANCES").
  - `title-1` for item names.
- **Trailing actions:** icons in `lime` (Share, the overflow menu).

**Android**
- **Bar:** small top app bar, `appbar-android` 64dp.
  - Left: a back arrow (`text`).
  - Middle: the title in `title-2`, truncated with an ellipsis.
  - Right: up to two action icons in `text`, then overflow.
- **Vault:** may use the large top app bar.

**Both**
- **Background:** `bg`, with a `hairline` bottom border once content scrolls under it.
- **No lime fills** in the bar, except the iOS Scan button.
