# TabBar

Primary navigation between Vault, Claims and Settings: an iOS tab bar or an Android navigation bar.

**iOS tab bar**
- **Size and look:** `tabbar-ios` 49pt plus the home-indicator inset, on `bg`, with a `hairline` top border.
- **Items:** `icon-md` icon over a `tab-label`.
  - Selected: `lime`.
  - Unselected: `text-subtle`.

**Android navigation bar**
- **Size and look:** `navbar-android` 80dp plus the gesture inset, on `bg`.
- **Selected item:** icon on a 64×32 `lime-tint` pill (`radius-pill`) in `lime`, with its label in `text`.
- **Unselected items:** `text-subtle`.
- **Labels:** always visible.

**Both**
- **Badge:** the Claims badge counts open claims needing action. It's a `signal` pill with an `on-lime` count, and shows nothing when the count is zero.
- **Icons:** the tab icons are the custom Vault, Claims and Settings icons in the Icons group. Don't use the platform's default icons.
- **Behaviour:** tapping the current tab scrolls it to the top.
- **Accessibility:** each tab's label includes the badge ("Claims, 3 need action").
