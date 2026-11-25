# PaperDrawer rebuild plan

design-v1 already runs one local drawer per account (`AccountDrawerApp` →
`DrawerStorage` → `DrawerRuntime`), with email sign-in, settings sync to
Supabase `profiles`, native Liquid Glass controls and a legacy drawer import.
The old "shared account" mode (`SharedSession`, `shared_router.dart`,
`shared_vault_*`) is only reachable from tests. The rebuild **reuses** that
runtime and moves it onto the new foundation, removes claims, and builds the
final Liquid Glass design for three plans.

Sources of truth:
- Product: "PaperDrawer — Plans, Accounts & Sync Spec" (Claude doc);
  summary in this file under "Decisions".
- Design: `design/ios-design-system.md`, the design-system tokens in
  `design/liquid-glass/` (dark values in `tokens.css`/`tokens.json`,
  components in `components/*/README.md`), and the final canvas boards in
  `design/canvas/*.dc.html` (light and dark twins; `canvas.json` lists board
  titles and the designer's notes). Open a board's HTML to read exact
  layout, copy, colours and spacing.
- Engineering rules: `AGENTS.md` (read all of it).

Per the owner's instruction, nothing is compiled or run until the end. Write
tests with every change.

## How the waves work

Each agent works in its own git worktree on a branch, changes **only the
files its wave owns**, commits, and reports. The coordinator merges the
wave, resolves conflicts, and delivers to the owner's Mac. Files to remove
are `git mv`-ed under `archive/<original path>` (excluded from analysis);
the coordinator moves them to `../#Archive/` on delivery.

If you need a change in a file you don't own, don't make it: list it in your
report under "Needed from other owners".

## Waves

### Wave 0 — Foundation (coordinator) — done
`lib/core/**`, `lib/domain/{plans,account,sync,reminders/notification_kind.dart}`,
`lib/data/{sync,errors,drawer}/**`, `lib/ui/core/failure_copy.dart`, tests.

### Wave 1 — parallel
**1A Claims and shared-mode removal.** Owns: every file in "Claims removal"
below (archive), plus the claim/shared edits in `app.dart`,
`drawer_runtime.dart`, `routing/router.dart`, `data/services/drawer_storage.dart`
(drop `ClaimRepository` only), `data/services/exporter.dart` (claims part:
export the raw claim tables instead of `List<Claim>`; remove `claimKit`),
`data/services/reminder_scheduler.dart` (claims parameter and claim
reminders only), `domain/item_status.dart` (claim parts only),
`ui/core/widgets/stamp.dart`, `ui/core/theme/type.dart` (`claimDay`),
`ui/features/settings/settings_screen.dart` and `settings_view_model.dart`
(claim parts only), `ui/features/vault/vault_tickets.dart`,
`vault_due_next.dart`, `ui/features/home/coming_up_screen.dart` (shared branch),
`ui/features/reminders/*` (shared inbox parts), and the tests listed for
deletion. Keep `retiredClaimLinks()` redirects. Keep reading claim tables
in export and legacy import (they become `*_v6_backup` in wave 2; until
then use the current names behind one constant per table).

**1B Plans, purchases and Apple sign-in (new files).** Owns:
`lib/domain/plans/*` (new files only), `lib/domain/account/*` (new files
only), `lib/data/purchases/**`, `lib/data/auth/**`, `pubspec.yaml`
(dependency additions only: `purchases_flutter`, `sign_in_with_apple`,
`crypto`), `test/domain/plans/*`, `test/data/purchases/**`,
`test/data/auth/**`. Builds:
- `PurchaseGateway` port (domain): products, `currentEntitlements()`,
  `purchase(product)`, `restore()`, `logIn(userId)`, `logOut()`,
  `Stream<Entitlements>`; all `Result`. `PurchaseProducts` constants
  (`essential_lifetime`, `pro_monthly`, `pro_yearly`).
- `RevenueCatPurchaseGateway` (data) mapping store errors to
  `PurchaseFailure` kinds (cancelled, pending, notAllowed, unavailable,
  storeError); `FakePurchaseGateway` for tests and the simulator.
- `EntitlementStore` port (domain): `load()`/`save(Entitlements)`; the
  SQLite implementation comes in wave 2. A `ProfilePlanGrant` mapper turns
  design-v1's `profiles.plan == 'pro'` into a `PlanGrant(store: web)`.
- `AuthGateway` port (domain): `currentSession()` (offline),
  `signInWithApple()`, `signInWithEmail`, `signUpWithEmail`,
  `resendConfirmation`, `signOut()`, `deleteAccount()`, `Stream` of auth
  changes; maps errors to `AuthFailure`. `SupabaseAuthGateway` (data) wraps
  design-v1's `SharedAccount` behaviour (Keychain session) and adds Apple
  sign-in through `signInWithIdToken` with a SHA-256 nonce; saves Apple's
  first-time name. Apple revoke on account deletion is a server call: leave
  a documented TODO and a `Result` failure, not a silent no-op.
- `PlanChangeExecutor` use case: runs `PlanChange` steps through ports
  (`SignInPrompt`, `MoveGuestItemsPrompt`, `SyncCoordinator`,
  `WebsiteNotifier`), never deletes local data, stops on the first `Err`
  and returns it.

**1C Notification rules (new domain files).** Owns:
`lib/domain/reminders/*` (except `notification_kind.dart`, which it may
extend), `test/domain/reminders/**`. Builds pure, tested:
- `NotificationPreferences` (per kind: on/off, lead days from
  `NotificationKind.leadDayChoices`; shared controls: time of day default
  09:00, last-day second reminder 18:00 default on, Time Sensitive on the
  last day default on, lock-screen detail default show; email copies on
  Pro), with defaults from `NotificationKind` and validation returning
  `ValidationFailure(leadTimeInvalid/timeOfDayInvalid)`.
- `ItemReminderSetting`: `defaults` | `custom(Map<NotificationKind, List<int>>)`
  | `muted`; mapping from design-v1 (`remind = 0` → muted, `reminder_at` →
  a custom time).
- `WindowType` ↔ `NotificationKind` mapping (componentWarranty ↔
  partWarranty, policyYear ↔ policyRenewal, term ↔ agreementTerm, …).
- `ReminderPlanner`: from items' cover windows, preferences, plan policy
  and `Clock`, produce the scheduled notifications: lead-time reminders at
  the time of day, the 18:00 last-day reminder, Time Sensitive on the last
  day, weekly summary (Monday), unfinished-item reminder (1 day after
  saving), Base backup reminder (60 days since export, then every 30);
  honour the iOS cap of 64 with deadlines first, nearest first; stable
  64-bit-safe IDs (not 31-bit hashes); payloads carry the account scope and
  a route (`/vault/item/<id>`). Migration helper: design-v1's single
  `lead_days` N → `[N]` for each deadline kind (2 → 3).
- Notification actions model: mark done, remind tomorrow, open item, mute
  item.

**1D Theme and glass kit (new files).** Owns: `lib/ui/core/theme/*` (new
files only), `lib/ui/core/layout/**`, `lib/ui/core/glass/**`,
`test/ui/theme/**`. Builds:
- `PdColors` `ThemeExtension` with `dark` (from `design/liquid-glass/tokens.css`)
  and `light` (read the `*Light.dc.html` boards against their dark twins:
  cream page `#F7F3DF`, warm tiles, olive `#465B16` wherever lime would be
  text; paper, tickets, lime buttons and the orange ticket identical in
  both), `PdSpace`, `PdRadius`, `PdTypeScale` built from the tokens;
  `context.pd` accessors; `pdThemeData(Brightness)`.
- `AppearanceMode { system, light, dark }` (domain or ui) and a
  `ThemeController` view model reading it from settings through a small
  port.
- Adaptive layout primitives: `PdBreakpoints` (compact < 600 pt, regular ≥
  600), `PdAdaptiveScaffold` (floating glass tab bar + Scan on compact; glass
  sidebar 320 pt with Home · Vault · Settings, Vault filters and "Scan or
  add" on regular), `PdContentWidth` (680 cap), two/three-column list
  helper.
- Glass components on top of the existing `native_liquid_glass` wrappers:
  `GlassScanButton` (lime tinted), `DeadlineAccessory`, `GlassToolbarButton`,
  `PdToast`, `PdGlassSheet` with Reduce Transparency/Increase Contrast
  fallbacks. Paper components without decoration: `DeadlineCard`,
  `ItemCardFlat`, `StatusLabel`, `PdMeterFlat`. Follow
  `design/liquid-glass/components/*/README.md`.
- Widget tests in both themes at iPhone 16 size and at 1180×820.

### Wave 2 — data (after wave 1 merges)
**2A Data layer.** Owns `lib/data/**` (except sync transports),
`lib/domain/models/**`, `lib/domain/item_status*.dart`,
`lib/drawer_runtime.dart`, the view-model call sites that break from data
API changes (`lib/ui/features/*/*_view_model.dart` only), and their tests.
Builds: schema v7 (sync columns on `items`/`attachments`; keyed `settings`
table backfilled from `preferences`; claim tables renamed `*_v6_backup`;
`preferences` → `preferences_v6_backup`; entitlements table; notification
preferences and per-item reminder settings; copy the file before
upgrading); `DrawerStore` on `DrawerPaths` returning `Result`; one shared
`SerialQueue` per drawer; `ItemRepository`, `SettingsRepository`,
`AttachmentStore`, `EntitlementRepository` on the `Repository` base with
`RowMapper`s, `Clock`, `IdGenerator`, capacity checked inside the write;
guest drawer always openable (replace the claimed-file lock with
per-row "moved" markers); unify legacy import with "Move items into
account"; Exporter from raw tables incl. claim backups; AccountSettingsSync
on the `settings` table (keep writing the derived `profiles` columns the
website still reads); `ReminderScheduler` driven by wave 1C's planner.

### Wave 3 — app shell (after wave 2)
**3A Composition root, theme migration and shell.** Owns `lib/main.dart`,
`lib/app.dart` → `lib/app/**`, `lib/ui/features/account/shared_app.dart`
(moved), `lib/routing/**`, `lib/ui/core/**`, `lib/ui/features/shell/**`, and
the mechanical `Pd.<colour>` → `context.pd.<colour>` migration across
`lib/ui/features/**` (no layout changes there). Builds the startup sequence
(session offline → open drawer → settings + cached plan → Home; network
afterwards), guest drawer in every build, Appearance applied, Home · Vault ·
Settings + floating Scan + DeadlineAccessory, regular-width sidebar, paper
decorations removed.

### Wave 4 — screens (parallel, after wave 3)
- **4A Home and Vault**: `lib/ui/features/home/**`, `lib/ui/features/vault/**`.
  Boards: Main, iOSHome*, iOSVault*, iPadHome*, Dev*.
- **4B Add, Camera, Reading, Item detail**: `lib/ui/features/add/**`,
  `lib/ui/features/item/**`. Merge the two item forms into one; wire Scan →
  Add sheet → Camera/Upload/Manual; Item › Reminders sheet. Boards:
  iOSAddSheet*, iOSCamera, iOSBillDetail, iOSItem*, iOSItemReminders*,
  iOSBaseLimit*.
- **4C Settings, Notifications, Appearance**: `lib/ui/features/settings/**`,
  `lib/ui/features/reminders/**`. Boards: iOSSettings*, iOSNotifications*,
  iOSNotifyReturns*, iOSNotificationsOff*, iOSAppearance*, iOSReminders*.
- **4D Accounts and intro**: `lib/ui/features/account/**` (except the moved
  app), `lib/ui/features/intro/**`. Sign in (Apple first, email), Create
  account, Move items into account, Sign out (keep / remove from this
  iPhone), Opening, Intro Keep/Remember. Boards: iOSSignIn*,
  iOSCreateAccount*, iOSMoveItems*, iOSSignOut*, iOSOpening*, iOSIntro*.
- **4E Plans and purchase**: `lib/ui/features/plans/**` (new). Plans,
  Essential sign-in-to-buy, Backing up, Pro welcome, Restore purchases,
  upgrade prompts. Boards: iOSPlans*, iOSEssentialBuy*, iOSBackingUp*,
  iOSProWelcome*.

### Wave 5 — sync transports (parallel, after wave 2)
- **5A Supabase (Pro)**: `lib/data/sync/supabase/**`, a SQL migration in
  `supabase/` for the sync columns and `user_settings`; outbox, field merge,
  attachment upload by content hash, contract tests.
- **5B CloudKit (Essential)**: `ios/Runner/CloudKit/**` (Swift CKSyncEngine
  plugin, iOS 17+, one zone per account, account-mismatch pause),
  `lib/data/sync/cloudkit/**` (method-channel transport), entitlements and
  capability notes, contract tests with a fake channel.

### Wave 6 — review (coordinator + reviewer agents)
Whole-app review against this plan and `AGENTS.md`; fix; deliver; the owner
runs format, analyze, test and a simulator build; fix what they find.

## Claims removal (wave 1A)

Archive: `lib/ui/features/claims/**`; `lib/ui/core/widgets/claim_ladder.dart`,
`gallery.dart`; `lib/ui/features/intro/art/claim_art.dart`;
`lib/domain/models/claim.dart`, `ledger.dart`; `lib/domain/ladders.dart`,
`claim_message.dart`; `lib/data/repositories/claim_repository.dart`;
`lib/data/services/ledger_pdf.dart`, `shared_claim_reminders.dart`. Shared
mode: `lib/routing/shared_router.dart`; `lib/ui/features/account/shared_session.dart`,
`shared_vault_screens.dart`; `lib/ui/features/vault/shared_vault_screen.dart`;
`lib/ui/features/add/shared_add_flow.dart`;
`lib/ui/features/settings/shared_settings_screen.dart`,
`shared_reminder_settings.dart`; `lib/data/services/shared_vault_service.dart`,
`shared_item_write.dart`, `shared_inbox_service.dart`;
`lib/data/repositories/shared_inbox_repository.dart`;
`lib/domain/models/shared_vault.dart`, `shared_notification.dart`.
Tests to archive: `test/data/claim_repository_test.dart`,
`claim_ledger_test.dart`; `test/ui/claim_ledger_test.dart`;
`test/domain/claim_message_test.dart`; `test/ui/intro/claim_art_test.dart`
(+ its golden); `test/domain/shared_vault_test.dart`;
`test/ui/shared_account_test.dart`, `shared_add_flow_test.dart`,
`shared_settings_screen_test.dart`, `shared_notification_inbox_test.dart`.
Keep the database tables (renamed in wave 2), `claim-photos/`, and
`retiredClaimLinks()`.

## Decisions the build relies on

Decided (spec 25 Nov 2026 + final canvas): local-first; never lose data;
Base = no account, 25 active items (warn from 20); Essential = Sign in with
Apple + iCloud; Pro = subscription + Supabase + website + email reminders;
settings synced for signed-in accounts; claims removed; light and dark
themes (Appearance defaults to System); tabs Home · Vault · Settings with a
floating Scan button.

Open in the spec, each built behind one switch so the answer is a one-line
change (agents never decide these):
- Essential one-time vs yearly: `PurchaseProducts.essential` (lifetime now).
- Essential email sign-in: `EssentialPolicy.signInMethods` (Apple only).
- Default lead times per kind: `NotificationKind.defaultLeadDays`.
- Offline entitlement grace: `Entitlements.offlineGrace` (14 days).
- Base originals in the iPhone backup: currently excluded (design-v1);
  one flag in the backup-exclusion setup.
- Other accounts' reminders on a shared phone: one strategy enum, default
  "keep with neutral text" (spec leaning).
- Family plan: not built; adding `Plan.family` makes every exhaustive
  switch fail until handled.
- Prices: placeholders from the store/RevenueCat, never hard-coded.

## Status

| Wave | Status |
|------|--------|
| 0 Foundation | Done (reviewed, fixes applied) |
| 1 Claims removal · Plans/auth ports · Notification rules · Theme/kit | Next |
| 2 Data | |
| 3 Shell | |
| 4 Screens | |
| 5 Sync transports | |
| 6 Review and verification | |
