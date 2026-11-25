# PaperDrawer rebuild plan

The app moves from two runtime modes (device-only SQLite, and a "shared
account" mode that reads Supabase directly) to one local-first app with
per-account databases, three plans and the Liquid Glass design. Claims are
removed.

Sources of truth:
- Product: "PaperDrawer — Plans, Accounts & Sync Spec" (Claude doc).
- Design: `design/ios-design-system.md` and the final canvas "PaperDrawer iOS
  — Liquid Glass screens" (light and dark).
- Engineering rules: `AGENTS.md`.

Each phase ends with its files on disk and `ARCHITECTURE.md` updated. Per the
owner's instruction, nothing is compiled or run until phase 8.

## Phases

| # | Phase | Status |
|---|-------|--------|
| 0 | **Foundation**: `lib/core` (Result, AppFailure, FailureMapper, Clock, IdGenerator, SerialQueue, Repository, RowMapper, SyncMetadata, ViewModel, ViewState, Command, UseCase, AppLogger); `domain/plans` (Plan, PlanPolicy for Base/Essential/Pro, ItemCapacity, Entitlements, ActivePlan, PlanChange); `domain/account/AccountScope`; `domain/reminders/NotificationKind`; `domain/sync` contracts; `data/sync` (NoSyncTransport, SyncCoordinator); `ui/core/failure_copy.dart`; tests | Written |
| 1 | **Data**: `DrawerStore` (open and close one `vault.db` per `AccountScope`, copy before migrating); schema v6 (sync columns on items, attachments, settings; claim tables kept as backups); `ItemRepository`, `SettingsRepository` and attachment storage rebuilt on the base classes; Export includes everything; archive claim and shared-mode code to `../#Archive/` | Next |
| 2 | **App shell**: composition root (`lib/app/`), startup sequence (saved session → open drawer → settings and cached plan → Home; network only afterwards), theme tokens for light and dark, glass kit, Home · Vault · Settings + Scan, adaptive layout (under 600 pt / 600 pt and up) | |
| 3 | **Core screens**: Home (empty, all clear), Vault (scrolled, empty, no results, filter empty), Add sheet, Camera, Reading and check, Item detail, Base drawer full | |
| 4 | **Notifications**: per-kind settings, per-item override (defaults, custom, muted), scheduler honouring the 64 cap (deadlines win), last-day and Time Sensitive, permission and "off in iOS" states | |
| 5 | **Settings and accounts**: Settings per plan, Appearance, Sign in and Create account (Apple first, email), Move items into account, Sign out (keep / remove from this iPhone), account switching | |
| 6 | **Plans and purchases**: Plans screen, purchase port (RevenueCat), Essential sign-in-to-buy, backing up, Pro welcome, entitlement caching, `PlanChange` executor | |
| 7 | **Sync transports**: Supabase (outbox, field merge, settings sync), CloudKit (Swift CKSyncEngine plugin) | |
| 8 | **Verify**: format, analyze, test, simulator build; fix everything; device checks | |

## Decisions the build relies on

Decided (spec 25 Nov 2026 + final canvas): local-first; never lose data;
Base = no account, 25 items (warn from 20); Essential = Sign in with Apple +
iCloud; Pro = subscription + Supabase + website; settings synced for
signed-in accounts; claims removed; light and dark themes.

Still open in the spec, built behind one switch so the answer is a one-line
change:
- Essential one-time vs yearly (`essential_lifetime` assumed).
- Essential email sign-in (`EssentialPolicy.signInMethods`, Apple only now).
- Default lead times per notification kind (`NotificationKind`).
- Offline entitlement grace (`Entitlements.offlineGrace`, 14 days).
- Base originals in the iPhone backup (decided in phase 1, needs owner OK).
- Family plan: not built; adding `Plan.family` makes every exhaustive switch
  fail until handled.
