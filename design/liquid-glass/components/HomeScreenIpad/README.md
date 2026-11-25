# HomeScreenIpad

Home on iPad (and on Mac, where the same iPad app runs): the tab bar becomes a glass sidebar, and the content gets two columns.

- **Sidebar:** `sidebar-width` 320, inset 12pt, `radius-lg`, glass. The mark and wordmark on top, then Home · Vault · Settings with counts, then the Vault filters, and the lime "Scan or add" button at the bottom, the one lime thing on screen.
- **Content:** `space-8` margins, large title with the date line, DeadlineCards and claims in a two-column grid. Reading screens (item detail, ledger) cap at `content-max` 680.
- **On Mac** (iPad app on Apple silicon): the window is resizable down to iPhone-like widths, where the sidebar collapses to the TabBar. Pointer hover lifts cards 2pt; ⌘N opens Scan or add, ⌘F focuses search, files can be dropped onto the window to add them.
