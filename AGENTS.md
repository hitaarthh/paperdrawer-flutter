# PaperDrawer Flutter: engineering rules

You are a senior mobile engineer on PaperDrawer: a drawer for bills,
warranties, insurance policies, vehicle papers and agreements that tracks the
dates that cost money (return windows, warranties, renewals, validity, terms).
The app is India-first and international-ready. iPhone, iPad and Mac (the iPad
app on Apple-silicon Macs) ship first. Android comes later from the same code.

These rules apply to every agent (Claude, Codex, others) and every human
working in this repo. They override generic skills. **The code is the source
of truth**: read the relevant part of `lib/` before changing it, and fix this
file or `ARCHITECTURE.md` in the same change if they are wrong.

The app is being rebuilt onto a new foundation. Read `docs/REBUILD_PLAN.md`
for the phase you are in before you start.

## 1. Preserve files and folders

- Never delete files or folders from the workspace, including hidden files
  and anything already archived.
- To remove or replace a file, move the original into `../#Archive/` first,
  keeping its workspace-relative path (for example
  `#Archive/paperdrawer-flutter/lib/ui/features/claims/claims_screen.dart`).
  If the destination exists, add a timestamp and keep both. Create
  `../#Archive/` if it does not exist.
- If the move fails, leave the original in place and report the blocker.
- This covers what you do to the workspace. It does not stop the app's own
  runtime code from deleting files inside its sandbox (for example cleaning up
  a failed attachment copy).

## 2. Product principles (non-negotiable)

Source: the "Plans, Accounts & Sync Spec" and the final iOS design canvas.

- **The phone's database is the main copy.** Every screen reads from and
  writes to local SQLite. Clouds only carry changes between devices and keep
  backups.
- **Nothing the user taps waits on the network.** Add, edit, archive, Home and
  Vault work offline and open instantly. Network work runs in the background.
- **Never lose data silently.** Sign-out, switching accounts, a plan ending or
  a refund never delete data on the phone unless the user explicitly chooses
  that, after a warning.
- **One account = one database file.** Each account (and the guest) has its
  own folder and `vault.db`, keyed by user ID. Never mix accounts in one file.
- **Three plans** (Family is a later proposal):
  - **Base**: free, no account, this device only, 25 active items (warn from
    20), export available.
  - **Essential**: paid once, Sign in with Apple, sync through the user's own
    iCloud (CloudKit).
  - **Pro**: subscription, sync through PaperDrawer cloud (Supabase), website
    vault, email reminders.
- **Private by default.** Logs and analytics never contain user content (item
  names, amounts, file names, emails). Count events, never contents.
- **PaperDrawer never contacts anyone for the user.** It drafts; the user
  sends.
- **Claims are removed.** Do not build, extend or route to claim features.
  Existing claim data is preserved in the database (see §7).
- **Calm, honest copy.** Short, specific, sentence case, typographic
  apostrophe (’), no exclamation marks, India-first examples (₹, `en_IN`
  grouping).

## 3. Layers and dependency direction

```
lib/
  core/      framework-free building blocks: Result, AppFailure, Clock,
             IdGenerator, SerialQueue, Repository base, RowMapper,
             ViewModel base, ViewState, Command, UseCase, AppLogger
  domain/    the business: immutable models and pure rules
             (plans/, account/, reminders/, sync/ contracts, items, dates)
  data/      the outside world: SQLite, files, plugins, network, sync
             transports, repositories (implementations of domain contracts)
  ui/        MVVM: view models + lean widgets, theme, kit, routes
  app/       composition root: builds the object graph, the one place that
             knows concrete classes
```

Allowed imports (enforced in review):

| Layer   | May import                                  | Must never import |
|---------|---------------------------------------------|-------------------|
| core    | Dart SDK, `flutter/foundation.dart`, `uuid` | domain, data, ui, plugins |
| domain  | core                                        | data, ui, plugins, sqflite, supabase |
| data    | core, domain, plugins, sqflite, supabase    | ui |
| ui      | core, domain, view-facing parts of data via providers | sqflite, supabase, plugins, `dart:io` |
| app     | everything                                  | — |

- Widgets never touch the database, files, plugins or the network. They talk
  to a view model, which talks to repositories and use cases.
- Domain code is pure Dart: no `async` I/O, no `DateTime.now()`, no plugins.
  It is where the rules live and where tests are cheapest.

## 4. Object-oriented design: use the base classes

Similar things must be built the same way. Do not hand-roll what a base class
already does; extend it. If no base class fits a recurring shape, add one to
`core/` (with tests) instead of copying code.

| You are building…                       | Extend / implement            | Pattern |
|-----------------------------------------|-------------------------------|---------|
| Storage for one kind of data            | `Repository<S>` (core/data)   | Template method: `readSnapshot` + `write` |
| Row ↔ model conversion for a table      | `RowMapper<T>` + `RowReader`  | Data mapper |
| A screen's state and actions            | `ViewModel` + `Command0/1`    | MVVM + command |
| What a screen shows                     | `ViewState<T>` (sealed)       | State |
| An action spanning repositories         | `UseCase<I, O>`               | Use case / facade |
| A plan's rules                          | `PlanPolicy` subclass (sealed)| Strategy |
| A way to sync                           | `SyncTransport` + factory     | Strategy + factory |
| "Nothing to do" variant                 | e.g. `NoSyncTransport`        | Null object |
| Turning exceptions into failures        | a `FailureRule`               | Chain of responsibility |
| A plugin or platform API                | an `abstract interface class` port in domain or data, implementation in data | Ports and adapters |

Class modifiers (Dart 3), so the type system enforces the design:

- `final class` by default for concrete classes.
- `abstract base class` for template bases that subclasses must extend, not
  re-implement (`Repository`, `RowMapper`, `Command`).
- `abstract interface class` for ports and contracts (`Clock`,
  `IdGenerator`, `SyncTransport`, `AppLogger`, `UseCase`).
- `sealed class` for closed sets that callers `switch` over (`Result`,
  `AppFailure`, `ViewState`, `PlanPolicy`, `ItemCapacity`, `SyncStatus`,
  `AccountScope`, `PlanChangeStep`). Every `switch` over them is exhaustive,
  with no `default` branch, so adding a case shows every place to update.
- `enum` with fields for fixed catalogues (`Plan`, `NotificationKind`,
  `ItemKind`).
- Value objects are `@immutable`, have `==`/`hashCode`, and are created
  through named constructors or factories that validate (for example
  `UserScope.parse`).

Other rules:

- **Dependency injection through constructors.** Collaborators (`Clock`,
  `IdGenerator`, `AppLogger`, `FailureMapper`, repositories, ports) come in
  through the constructor. No singletons, no service locators, no static
  mutable state. `provider` only exposes what the composition root built.
- **Ask the policy, don't check the plan.** Never write
  `if (plan == Plan.pro)`. Ask `activePlan.policy` a question
  (`itemLimit`, `syncKind`, `channelsFor(kind)`). If no getter answers it,
  add one to `PlanPolicy`; every subclass must then answer it.
- **Small units.** A class has one reason to change. Keep files under ~300
  lines and methods under ~40; split before you pass them.
- **No logic in widgets.** Derived values (labels, counts, colours chosen by
  status) are getters on the view model or domain objects.

## 5. Errors and failure cases

- **Expected failures are values.** Repositories, services, use cases and
  commands return `Result<T>`; they never throw for expected failures
  (validation, not found, limit reached, no space, no network, permission
  denied, cancelled, sync paused).
- **Exceptions are for bugs only** (broken invariants). They are caught at
  the boundary (`Repository.write`, `Command`) and become
  `UnexpectedFailure`, so the UI always recovers.
- **Map at the edge.** Every call into sqflite, the file system, a plugin or
  the network goes through a `FailureMapper` (add a `FailureRule` for new
  error types). View models never see a raw exception.
- **Inside a DB transaction**, abort with `throw FailureException(failure)`
  so the transaction rolls back and the caller still gets `Err(failure)`.
- **Failures carry codes, not copy.** All user-facing words for failures live
  in `ui/core/failure_copy.dart`. Silent failures (`CancelledFailure`,
  `ScopeClosedFailure`, cancelled sign-in or purchase) show nothing.
- **Every operation that writes must state its failure cases** in its doc
  comment and have a test for each.
- **No orphans.** A failed write leaves no copied files and no half-saved
  rows: copy files first, write rows in one transaction, clean up copies on
  failure.
- **After a committed write**, a failed refresh is not a failed write (the
  base `Repository` handles this; don't report it as an error).
- **Async UI.** After every `await` in a `State`, check `mounted`. Commands
  prevent double submits; don't add ad-hoc `_busy` flags.

## 6. Time, IDs, money

- "Now" comes only from an injected `Clock` (`now()` for instants,
  `today()` for the civil date). `DateTime.now()` appears only inside
  `SystemClock`.
- Deadlines are civil dates (`yyyy-mm-dd`), never instants. Instants are
  epoch milliseconds.
- IDs come only from an injected `IdGenerator` (UUID v4 created on the
  phone). They never change and are how sync, import and export match rows.
- Money is integer minor units plus an ISO currency code. Never a double.

## 7. Data

- Each account's data lives in `drawers/<folder>/vault.db` and
  `drawers/<folder>/originals/` under Application Support, where `<folder>`
  is `guest` or the user's UUID (`AccountScope`). Store **relative** paths
  only.
- Every synced table carries the sync columns (`id`, `created_at`,
  `updated_at`, `deleted_at`, `dirty`, `field_updated_at`, and `drawer_id`
  when Family arrives). Read and write them only through `SyncMetadata` and
  `RowMapper.syncColumns`.
- Deletes of synced records are markers (`deleted_at`), not row deletes,
  except when a remote delete marker is applied or a marker is purged after
  every device has synced.
- **Migrations never drop user data.** Rename old tables to
  `<name>_vN_backup` and keep them. Before upgrading a file's schema, copy
  the file and keep the copy until the upgrade succeeds. Each migration gets
  a test that upgrades a populated database from the previous version and
  checks every row survived.
- Claims: the `claims`, `claim_events` and `claim_event_photos` tables stay
  in the database (renamed to backups) so no user data is lost, and they are
  included in Export. No UI reads them.
- Exactly one sync transport runs at a time, through `SyncCoordinator`.
  Background results tagged with a closed account are dropped.

## 8. UI

Design sources: `design/ios-design-system.md` (Liquid Glass), the final
canvas "PaperDrawer iOS — Liquid Glass screens", and the token files. Where
they disagree, the canvas wins (it adds the light theme; Appearance defaults
to System).

- Three layers: the **room** (background), **paper** (content: items,
  tickets, receipts), **glass** (controls only: tab bar, Scan, toolbar
  buttons, sheets, toasts, iPad sidebar, camera controls). Never glass on
  content, never paper on controls.
- One action colour (lime). Orange only means a deadline is close. Errors
  use `danger`, never orange.
- Native first: use the iOS 26 system control where one exists, tinted with
  tokens. Fall back to the kit's glass only below iOS 26 or where the system
  has none.
- Style only with tokens and type styles from `ui/core/theme/`. No
  hard-coded colours, font sizes or spacing in widgets. Both themes must work
  for every screen except Camera (dark in both).
- Layout follows available width, not device: under 600 pt one column with
  the floating tab bar; 600 pt and up, sidebar and two or three columns.
- Every screen handles all `ViewState` cases plus its empty states. Give
  interactive widgets tests drive a `ValueKey('kebab-name')`.
- Dynamic Type up to the largest accessibility size, Reduce Transparency,
  Reduce Motion and Increase Contrast are part of done, not polish.
- Imports: `package:material_ui/material_ui.dart` and
  `package:cupertino_ui/cupertino_ui.dart`, not the deprecated
  `flutter/material.dart` and `flutter/cupertino.dart`.
- Navigation through `go_router` in `lib/routing/`. Sheets and dialogs
  through the kit helpers.

## 9. Tests

- **Domain:** unit tests for every rule and every edge (limits at 19, 20,
  24, 25; expiry exactly at the grace boundary; month-end and leap days).
- **Core and data:** repositories against `sqflite_common_ffi` in a temporary
  directory, including a reopen check, a failure-injection case for each
  failure the method documents, and the serial-queue ordering.
- **Contracts:** any interface with several implementations (for example
  `SyncTransport`) has a shared contract test that runs against each.
- **UI:** widget tests with in-memory fakes at iPhone 16 size (1179×2556 at
  3× DPR, padding top 177, bottom 102), plus a 1.3× text-scale overflow check,
  in both themes.
- Fakes implement the same interfaces as the real classes. No mocking of
  concrete classes.
- Test names state the behaviour ("Pro ending falls back to owned
  Essential"), not the method.

**Rebuild mode (current):** the owner asked that nothing be compiled or run
until the rebuilt app is complete. During the rebuild, write tests with every
change but do not run `flutter analyze`, `flutter test` or builds. At the end
of the rebuild, run the full definition of done below and fix everything it
finds before reporting the rebuild as done. Remove this paragraph then.

## 10. Definition of done

```sh
dart format lib test
flutter analyze            # must report "No issues found!"
flutter test               # all tests pass
flutter build ios --simulator --debug   # for native or plugin changes
```

Plus: tests for new behaviour (§9), `ARCHITECTURE.md` updated for any
changed contract, route, schema or kit component, and a short report of what
changed, why, how it was verified, and what was not verified (for example
"CloudKit needs a physical device and an Apple developer account").

Do not commit, push or create branches unless the owner asks.

## 11. Repo skills

Skills live in `.agents/skills/`. They predate the rebuild: where a skill
mentions claims, the shared-account mode, throwing `FormatException`, or
dark-only UI, this file wins. Update a skill when you touch its area.

- `mobile-feature-delivery`: the end-to-end feature workflow.
- `paperdrawer-design-system`: building or changing UI.
- `paperdrawer-local-data`: schema changes, migrations, attachments,
  repositories.
- `mobile-platform-integration`: permissions, plugins, native channels,
  notifications, iOS and Android config.
- `mobile-verify`: running checks, the simulator, screenshots, reporting.
- `mobile-code-review`: reviewing a diff as a senior mobile engineer.
