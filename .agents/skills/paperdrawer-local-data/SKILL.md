---
name: paperdrawer-local-data
description: Rules and recipes for PaperDrawer's on-device data layer, covering the SQLite schema and migrations, the repository boundary, attachment file storage, backup exclusion, encoding of dates and money, and data-safety tests. Use when adding a field or table, changing how items, claims, or attachments are stored, writing a migration, adding a repository method, or building export or import.
---

# PaperDrawer local data

All user data lives on the device under `<Application Support>/paperdrawer/`.
The database (sqflite) and the attachment originals live there, for example
`paperdrawer/attachments/<itemId>-<uuid>.<ext>`.

The database stores attachment paths **relative** to the vault directory, and
the repository joins them back into a full path when it reads. Never persist an
absolute path, because the iOS container path changes between installs and
restores.

The first version (`../#Archive/paperdrawer-flutter/lib/src/data/`) shows these
patterns working, with copy-then-insert and cleanup on failure. Read it for
reference only.

## The boundary

- Widgets never touch the database or the file system. They go through view
  models, which call repositories.
- Define a repository interface in `lib/data`, then the SQLite
  implementation. Every interface change updates the in-memory fakes used in
  tests.
- Validate at the repository: trim strings, check required fields, and throw a
  `FormatException` with a user-facing message for bad input, or a
  `StateError` for impossible states such as a missing row.
- Serialize writes that must not interleave, either with a single queue or
  with database transactions.

## Schema changes (migrations)

Every schema change must follow these steps:

1. Bump `version` in `OpenDatabaseOptions`.
2. Keep `onCreate` building the **latest** schema for fresh installs.
3. Add an `onUpgrade` that steps through each version in turn:
   ```dart
   onUpgrade: (db, from, to) async {
     if (from < 2) {
       await db.execute('ALTER TABLE items ADD COLUMN reminder_at INTEGER');
     }
     if (from < 3) { /* ... */ }
   },
   ```
4. Prefer additive changes, such as a nullable column or a column with a
   `DEFAULT`. Rename or drop a column with the create-copy-swap pattern inside
   a transaction, never with a destructive shortcut.
5. Add `CHECK` constraints that match the domain enums (for example `ItemKind`
   and `ClaimStatus` names). Use foreign keys with `ON DELETE` rules for child
   tables such as claim events, and turn them on with `PRAGMA foreign_keys = ON`
   in `onConfigure`.
6. Add an index when a query filters or sorts on a column that the current
   indexes do not cover. Deadlines and status are the likely candidates.
7. **Test the upgrade.** Create a database with the old version's SQL, insert
   rows, reopen it through the repository, and assert that the rows survived
   and the new columns have their defaults.

Never ship a change that drops or recreates a table holding user data without
an explicit, tested data copy. Before the first release the schema may still
change freely, but once a build has reached a user's device, migrations are
mandatory.

## Types and encoding

- **Civil dates** (bill date, warranty end, policy renewal, PUC validity) are
  stored as `TEXT` in `YYYY-MM-DD` form, through `isoDate()` and
  `parseIsoDate()` in `lib/domain/formats.dart`. They carry no time zone.
- **Instants** (created, archived, claim events, reminder fire times) are
  stored as `INTEGER` milliseconds since the epoch.
- **Money** is stored as `INTEGER` minor units plus a `TEXT` currency code
  (default `INR`). Never store it as a floating-point number. Format it only in
  the UI layer.
- **Enums** are stored by `.name`. When old data could hold an unknown value,
  decode with a tolerant fallback.
- **Single settings** go in a key and value `preferences` table. Do not add a
  new table for each setting.

## Attachments

- Validate the type (photo or PDF) and the size before you copy. The first
  version used a limit of 20 MB.
- Copy files out of temporary picker storage into `attachments/` right away.
  Picker paths do not last.
- When a write fails, delete the file you just copied. When you replace an
  attachment, delete the old file only after the database commit.
- Archiving never deletes originals.

## Privacy and backup

- The vault folder is excluded from iCloud and iTunes backups through a
  native method channel at startup. Any new folder must live inside
  `paperdrawer/` so the exclusion covers it.
- Exports (a zip through `archive`, the share sheet through `share_plus`)
  happen only when the user explicitly starts them. Write the export to a
  temporary directory, hand it to the share sheet, and do not keep plaintext
  copies anywhere else.
- Do not add a remote database, sync, or analytics.

## Tests

Use `sqflite_common_ffi` (`sqfliteFfiInit()` and `databaseFactoryFfi`) with
`Directory.systemTemp.createTemp`, and `addTearDown` to close the database and
delete the directory. Always include a close-and-reopen assertion. The archived
`test/sqlite_vault_repository_test.dart` is a working template.
