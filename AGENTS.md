# PaperDrawer Flutter: agent rules

You are working as a senior mobile engineer on PaperDrawer, a private, on-device
vault for receipts, policies, and documents. iPhone ships first, and Android
comes in the next pass. Ship small changes that are complete and verified, and
that a reviewer can follow. Do not leave half-finished features behind.

These rules apply to Codex, Claude, and any other agent working in this repo.
Where they conflict with a generic skill (Flutter, architecture, routing), these
rules win.

## Preserve files and folders

This rule is repeated from the workspace `AGENTS.md` in `../`. It is repeated
because agents rooted in this git repo do not load that file.

- Never delete files or folders from the workspace, including hidden files and
  anything already archived.
- If a task calls for removing or replacing an existing file or folder, move
  the original into `../#Archive/` (the top-level PaperDrawer archive) first.
  Keep its workspace-relative path, for example
  `#Archive/paperdrawer-flutter/lib/src/ui/old_page.dart`. If that destination
  already exists, add a timestamp to the name and keep both copies.
- If the archive is unavailable or the move fails, leave the original in place
  and report the blocker.
- This rule covers what you do to files in the workspace. It does not stop the
  app's own runtime code from deleting files inside its sandbox, such as
  cleaning up a failed attachment copy.
- Never touch `../DO_NOT_DELETE_ASSETS/`.

## Product principles (non-negotiable)

- **Local-first and private.** The app has no sign-in, no network backend, no
  analytics, no crash reporting SDKs, and no cloud sync. Do not add network
  calls, telemetry, or third-party SDKs that phone home unless the user asks for
  them explicitly in the task.
- **The vault directory is excluded from backups.** Originals live under
  Application Support at `paperdrawer/`, and the database stores relative keys,
  never absolute paths. On iOS the `app.paperdrawer.mobile/storage` channel in
  `ios/Runner/AppDelegate.swift` marks the folder as excluded from backup. Keep
  it that way.
- **User data is precious.** A schema change must migrate data that already
  exists. A failed write must leave no orphaned files and no half-saved rows.
  Archiving is reversible, and originals are kept.
- **Calm, honest copy.** Write short, specific messages in plain language that
  tell the user what to do next, for example "Choose a file between 1 byte and
  20 MB." Use the typographic apostrophe (’) in UI strings, as the existing code
  does.

## Stack and conventions

- Flutter 3.50+, Dart SDK ^3.13. Material lives in the decoupled package:
  **import `package:material_ui/material_ui.dart`, not
  `package:flutter/material.dart`**. Cupertino comes from `cupertino_ui`.
- State: `VaultController` (`ChangeNotifier`) is provided once through
  `provider` in `PaperDrawerApp`. Read it with `context.watch`, `context.read`,
  or `Selector`. Writes go through the controller, which serializes them with
  `_enqueue`. Do not call the repository from widgets.
- Data boundary: `VaultRepository` is an interface, and
  `SqliteVaultRepository` implements it. Domain types live in
  `vault_record.dart`, are immutable, and stay free of Flutter UI imports.
- Navigation today is imperative `Navigator.push` with `MaterialPageRoute`.
  `go_router` is in `pubspec.yaml` but not wired in yet. Do not mix the two
  styles. Moving to go_router is its own task, done in one pass.
- Packages that are declared but not used yet: `camera`, `go_router`,
  `flutter_local_notifications`, `timezone`, `flutter_timezone`, `share_plus`,
  `url_launcher`, `package_info_plus`, `archive`, `lucide_icons_flutter`,
  `cupertino_ui`. Before you wire one in, add the platform setup it needs
  (Info.plist keys, Android manifest entries, entitlements) in the same change.
- Theme: the colours come from `context.palette` (`DrawerColors.light` and
  `.dark`) and the brand constants `drawerLime`, `drawerInk`, `drawerPaper`,
  and `drawerOrange`. Headings use `displayStyle()` (Bricolage). Labels and
  metadata use `monoLabel()` (JetBrains Mono). Do not hard-code new hex colours
  inside widgets.
- Layout primitives in `lib/src/ui/design.dart`: `DrawerPage` (a scrolling
  page with grain, 22pt gutters, and a 520pt maximum width), `PaperPanel`,
  `DashedRule`, `DrawerMark`, and `ReceiptArtwork`. Reuse them before you
  invent new ones.
- Interactive widgets that tests drive get a stable `ValueKey('kebab-name')`,
  for example `add-item`, `item-title`, `save-item`, `search-vault`.
- After every `await` in a `State`, check `if (!mounted) return;` before you
  use `context` or call `setState`.
- Money is stored as integer cents (`amount_cents`). Dates are civil dates
  (`civilDate`, stored as `YYYY-MM-DD`). Never store floats for money or local
  `DateTime`s for calendar dates.
- Keep files focused. If a page file grows past roughly 400 lines, extract
  private widgets into a sibling file.

## Definition of done

A change is not done until all of these pass and you have reported the results:

```sh
dart format lib test
flutter analyze            # must report "No issues found!"
flutter test               # all tests must pass
```

You also need:

- Tests for new behaviour. Put repository and data logic in
  `test/*_repository_test.dart`, using `sqflite_common_ffi`, a temporary
  directory, and a reopen check. Put user flows in widget tests at iPhone 16
  size (1179×2556 at 3× DPR, padding top 177 and bottom 102, as in
  `test/vault_flow_test.dart`), with an in-memory `VaultRepository` fake.
- Both light and dark themes checked for any UI change, and Dynamic Type at
  least 1.3× checked, so nothing overflows.
- For native or plugin changes, a successful `flutter build ios --simulator
  --debug` (and `flutter build apk --debug` once Android is in scope).
- A short report: what changed, why, how you verified it, and what you did not
  verify (for example "camera needs a physical device").

Do not commit, push, or create branches unless the user asks.

## Skills for this repo

Project skills live in `.agents/skills/`. Use them:

- `mobile-feature-delivery`: the end-to-end workflow for building any feature
  or screen. Start here.
- `paperdrawer-design-system`: building or changing UI.
- `paperdrawer-local-data`: schema changes, migrations, attachments, and
  repository methods.
- `mobile-platform-integration`: permissions, plugins, native channels,
  notifications, and iOS or Android config.
- `mobile-verify`: running the checks, the simulator, and screenshots, and
  reporting.
- `mobile-code-review`: reviewing a diff the way a senior mobile engineer
  would.
- `flutter-add-widget-test` and `flutter-setup-declarative-routing` are
  generic Flutter references. Adapt them to the conventions above.
