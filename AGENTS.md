# PaperDrawer Flutter: agent rules

You are working as a senior mobile engineer on PaperDrawer, a private,
on-device drawer for bills, policies, vehicle papers, and agreements. It
tracks the cover windows on those papers (return windows, warranties, policy
years, validity, terms) and helps people pursue claims through escalation
ladders. The app is India-first, and iPhone ships first. Android comes in the
next pass.

Ship small changes that are complete and verified, and that a reviewer can
follow. Do not leave half-finished features behind.

These rules apply to Codex, Claude, and any other agent working in this repo.
Where they conflict with a generic skill (Flutter, architecture, routing), these
rules win. **The code is the source of truth.** Read the relevant part of
`lib/` before you change it. If this file or `ARCHITECTURE.md` is wrong about the
code, fix it as part of your change.

## Preserve files and folders

This rule is repeated from the workspace `AGENTS.md` in `../`. It is repeated
because agents rooted in this git repo do not load that file.

- Never delete files or folders from the workspace, including hidden files and
  anything already archived.
- If a task calls for removing or replacing an existing file or folder, move
  the original into `../#Archive/` (the top-level PaperDrawer archive) first.
  Keep its workspace-relative path, for example
  `#Archive/paperdrawer-flutter/lib/src/ui/app.dart`. If that destination
  already exists, add a timestamp to the name and keep both copies.
- If the archive is unavailable or the move fails, leave the original in place
  and report the blocker.
- This rule covers what you do to files in the workspace. It does not stop the
  app's own runtime code from deleting files inside its sandbox, such as
  cleaning up a failed attachment copy.
- Never touch `../DO_NOT_DELETE_ASSETS/`.
- `../#Archive/paperdrawer-flutter/` holds the first version of the app. Read
  it for reference only (data-safety patterns, tests). Do not import from it.

## Product principles (non-negotiable)

- **Local-first and private.** Drawer records and originals live on the device.
  Supabase handles account authentication and synchronizes shared account
  settings. Do not add vault sync, telemetry, analytics, or crash reporting
  without an explicit request.
- **PaperDrawer never contacts anyone for the user.** Claims and ladders
  suggest steps and draft messages. The user sends them, through the share
  sheet, mail, or phone.
- **The vault stays on the device and out of backups.** Store originals under
  Application Support (`paperdrawer/`), and keep only **relative** paths in
  storage. On iOS, exclude the vault folder from backup through a native
  channel, as the first version did with `app.paperdrawer.mobile/storage`.
- **User data is precious.** Every schema change migrates the data that already
  exists. A failed write leaves no orphaned files and no half-saved rows.
  Archiving is reversible, and originals are kept.
- **Calm, honest copy.** Write short, specific messages in plain language that
  tell the user what to do next. Use the typographic apostrophe (’). Use
  India-first examples, currency (₹, `en_IN` grouping), and escalation routes.

## Architecture

**`ARCHITECTURE.md` is the contract.** It covers the folder layout, the
database schema and migrations, the repository and service APIs, the routes,
and the UI kit. Read the parts you will touch before you change code. If you
change a contract, update `ARCHITECTURE.md` in the same change. The design
source is `design/mobile-system/` (`README.md`, `platforms.md`, `screens.md`,
`tokens.json`, `components/`).

The invariants to keep in mind:

- The layering runs **data** (services and repositories, the single source of
  truth), then **domain** (immutable models and pure logic, unit-tested), then
  **ui** (ChangeNotifier view models and lean views, in
  `lib/ui/features/<feature>/`). Dependencies are injected with `provider`.
  Widgets never touch the database, files, or plugins directly.
- Repositories hold an in-memory snapshot, write through to SQLite, serialize
  writes through one queue, and notify listeners after each successful write.
  `FormatException.message` is always user-facing copy.
- Calendar dates are civil dates (`isoDate` / `parseIsoDate`, `yyyy-mm-dd`).
  "Today" comes from the `Today` service, never from `DateTime.now()` scattered
  through the code. Instants are milliseconds since the epoch. Money is stored
  as integer minor units plus a currency code. Never store money as a
  floating-point number.

## Stack and conventions

- Flutter 3.50+, Dart SDK ^3.13. Material lives in the decoupled package:
  import `package:material_ui/material_ui.dart`, not
  `package:flutter/material.dart`. Cupertino comes from `cupertino_ui`. Pure
  domain files import only `package:flutter/foundation.dart` (for
  `@immutable`), or nothing at all.
- Read the `pubspec.yaml` packages before you add one. Prefer what is already
  declared. Before you wire in a plugin, add the platform setup it needs
  (Info.plist keys, Android manifest entries, entitlements) in the same change.
- Navigation uses `go_router` (`lib/routing/router.dart`, with
  `StatefulShellRoute` for the tabs). Add routes there. Do not push
  `MaterialPageRoute`s for screens. Modal sheets and dialogs go through the
  kit helpers (`showPdSheet`, `showPdActions`, `showPdConfirm`).
- Styling: build from the UI kit in `lib/ui/core/widgets/` (`PdButton`,
  `ReceiptPaper` and `DocumentPaper`, `ItemCard`, `PdStamp`, `PdMeter`,
  `PdTextField`, `PdListRow`, `showPdSnackbar`, `PdLargeTitleScaffold`, and
  others), and use only `Pd` tokens and `PdType` styles. Do not hard-code hex
  colours, font sizes, or magic spacing inside widgets. Icons are `PdGlyph`
  for tab and scan icons, `LucideIcons` for everything else, and
  `CupertinoIcons` for share and back. The app is dark-only at launch ("paper is the
  content, dark is the room").
- Interactive widgets that tests drive get a stable `ValueKey('kebab-name')`.
- After every `await` in a `State`, check `if (!mounted) return;` before you
  use `context` or call `setState`.
- Keep files focused. If a file grows past roughly 400 lines, split it.

## Definition of done

A change is not done until all of these pass and you have reported the results:

```sh
dart format lib test
flutter analyze            # must report "No issues found!"
flutter test               # all tests must pass
```

You also need:

- Tests for new behaviour. Domain rules get unit tests. Repositories get tests
  against `sqflite_common_ffi` and a temporary directory, with a reopen check.
  User flows get widget tests at iPhone 16 size (1179×2556 at 3× DPR, padding
  top 177 and bottom 102) using in-memory fakes.
- A check at a 1.3× text scale for any UI change, so nothing overflows.
- For native or plugin changes, a successful
  `flutter build ios --simulator --debug`.
- An updated `ARCHITECTURE.md`, if you changed a contract, route, schema, or
  kit component.
- A short report: what changed, why, how you verified it, and what you did not
  verify (for example "camera needs a physical device").

Do not commit, push, or create branches unless the user asks.

## Skills for this repo

Project skills live in `.agents/skills/`. Use them:

- `mobile-feature-delivery`: the end-to-end workflow for building any feature
  or screen. Start here.
- `paperdrawer-design-system`: building or changing UI.
- `paperdrawer-local-data`: schema changes, migrations, attachments, and
  repositories.
- `mobile-platform-integration`: permissions, plugins, native channels,
  notifications, and iOS or Android config.
- `mobile-verify`: running the checks, the simulator, and screenshots, and
  reporting.
- `mobile-code-review`: reviewing a diff the way a senior mobile engineer
  would.
- `flutter-add-widget-test` and `flutter-setup-declarative-routing` are
  generic Flutter references. Adapt them to the conventions above, for example
  by swapping `flutter/material.dart` for `material_ui`.
