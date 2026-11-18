---
name: paperdrawer-local-data
description: Rules and recipes for PaperDrawer's on-device data layer, covering the SQLite schema and migrations, the VaultRepository boundary, attachment file storage, backup exclusion, and data-safety tests. Use when adding a field or table, changing how records or attachments are stored, writing a migration, adding a repository method, or building export or import.
---

# PaperDrawer local data

All user data lives on the device under
`<Application Support>/paperdrawer/`:

```
paperdrawer/
  vault.sqlite              # records + preferences tables
  attachments/<recordId>-<uuid>.<ext>
```

The database stores attachment paths **relative** to the vault directory
(`attachment_key`). `_decode` joins them back into a full path. Never persist
an absolute path, because the iOS container path changes between installs and
restores.

## The boundary

- Widgets never call the repository. They go through `VaultController`, which
  serializes writes with `_enqueue`.
- `VaultRepository` (`lib/src/data/vault_repository.dart`) is the contract.
  Add the method there first, then implement it in `SqliteVaultRepository`,
  then update every fake in `test/`.
- Validate at the repository: trim strings, check required fields, and throw a
  `FormatException` with a user-facing message for bad input, or a
  `StateError` for impossible states such as a missing record.

## Schema changes (migrations)

The current schema is version 1. Every schema change must follow these steps:

1. Bump `version` in `OpenDatabaseOptions`.
2. Keep `onCreate` building the **latest** schema for fresh installs.
3. Add an `onUpgrade` that steps through each version in turn:
   ```dart
   onUpgrade: (db, from, to) async {
     if (from < 2) {
       await db.execute('ALTER TABLE records ADD COLUMN reminder_at INTEGER');
     }
     if (from < 3) { /* ... */ }
   },
   ```
4. Prefer additive changes, such as a nullable column or a column with a
   `DEFAULT`. Rename or drop a column with the create-copy-swap pattern inside
   a transaction, never with a destructive shortcut.
5. Add `CHECK` constraints that match the domain enums, as `kind` does.
6. Add an index when a new query filters or sorts on a column that the current
   indexes do not cover, and the table could grow to thousands of rows.
7. **Test the upgrade.** Create a database with the old version's SQL, insert a
   row, reopen it through `SqliteVaultRepository.open`, and assert that the row
   survived and the new column has its default.

Never ship a change that drops or recreates a table holding user data without
an explicit, tested data copy.

## Types and encoding

- Money is stored as `INTEGER` cents and is non-negative. Parse it with
  `parseAmountCents`.
- Calendar dates (`recorded_on`, `deadline`) are stored as `TEXT` in
  `YYYY-MM-DD` form via `civilDate`. They carry no time zone. Instants
  (`created_at`, `archived_at`, and future reminder times) are stored as
  `INTEGER` milliseconds since the epoch.
- Store enums by `.name`, and decode them with `values.byName`. When old data
  could hold an unknown value, decode with `firstWhere(..., orElse:)`.
- Preferences go in the `preferences` key and value table. Do not add new
  tables for single settings.

## Attachments

- Accepted types are `attachmentExtensions` (pdf, jpg, jpeg, png, heic, heif,
  webp) with a size of at most `maxAttachmentBytes` (20 MB). Validate both
  before you copy.
- Copy files out of temporary picker storage into `attachments/` right away.
  Picker paths do not last.
- When a write fails, delete the file you just copied, as `save()` does. When
  you replace an attachment, delete the old file only after the database update
  has committed.
- Archiving never deletes originals.

## Privacy and backup

- The vault folder is excluded from iCloud and iTunes backups through the
  `excludeFromBackup` method channel, which `main.dart` calls at startup on iOS.
  Any new folder must live inside `paperdrawer/` so the exclusion covers it.
- Export features (zip through `archive`, the share sheet through
  `share_plus`) must happen only when the user explicitly starts them. Write
  the export to a temporary directory, hand it to the share sheet, and do not
  keep plaintext copies anywhere else.
- Do not add a remote database, sync, or analytics.

## Tests

Use `sqflite_common_ffi` (`sqfliteFfiInit()` and `databaseFactoryFfi`) with
`Directory.systemTemp.createTemp`, and `addTearDown` to close the repository
and delete the directory. Copy `test/sqlite_vault_repository_test.dart`, and
always include a close-and-reopen assertion.
