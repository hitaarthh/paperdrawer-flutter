---
name: mobile-feature-delivery
description: End-to-end senior mobile engineering workflow for adding a feature, screen, or flow to the PaperDrawer Flutter app, from understanding the request through data, state, UI, platform setup, tests, and verification. Use when asked to add, build, create, implement, or extend anything user-facing in PaperDrawer (for example reminders, OCR, sharing, export, search, filters, new record fields, or new pages).
---

# Delivering a mobile feature in PaperDrawer

Work like a senior mobile engineer. Understand the request before you write
code, change each layer of the app in order, handle the unhappy paths, and
prove that the result works. Read `AGENTS.md` at the repo root first. Its rules
override anything here.

## 1. Frame the change (before you write code)

Write a short plan for yourself, and share it with the user when the change is
large or ambiguous:

- **User outcome.** In one sentence, what can the user do afterwards?
- **Layers touched.** Mark each one yes or no: domain types
  (`vault_record.dart`), repository interface, SQLite schema or migration,
  controller, UI, native or platform config, tests.
- **States.** List the empty, loading, success, error, and offline-irrelevant
  states. Also cover what happens with 0 records, 1 record, and 500 records,
  and with very long titles.
- **Platform impact.** Note any permission prompts, Info.plist or
  AndroidManifest changes, background behaviour, and whether the feature needs
  a physical device.
- **Privacy check.** Does anything leave the device? If so, stop and confirm
  with the user. See the product principles in `AGENTS.md`.
- **Smallest shippable slice.** Name it. Build that slice completely before you
  add anything else.

Ask the user only about decisions that are genuinely theirs to make, such as
product behaviour or copy that changes meaning. Decide the conventional
engineering choices yourself, and say what you chose.

## 2. Build from the bottom up

Change one layer at a time, and keep the build green as you go.

1. **Domain.** Add fields or enums to the immutable types in
   `lib/src/data/vault_record.dart`. Pure formatting and parsing helpers
   (like `parseAmountCents`) belong here and get unit tests.
2. **Repository.** Extend the `VaultRepository` interface first, then
   `SqliteVaultRepository`. Any schema change follows the
   `paperdrawer-local-data` skill, which covers bumping the version, adding an
   `onUpgrade`, and testing an upgrade from the old schema.
3. **Controller.** Add methods to `VaultController` that run through
   `_enqueue`, refresh state from the repository, and call `notifyListeners()`
   once. Expose derived data as getters (as `active` and `archive` do) rather
   than computing it in widgets.
4. **UI.** Follow the `paperdrawer-design-system` skill. Build the page from
   `DrawerPage`, `PaperPanel`, the palette, and the type helpers. Give every
   interactive element tests use a `ValueKey`. Handle every state you listed in
   step 1.
5. **Platform.** For any plugin or native work, follow the
   `mobile-platform-integration` skill. Make the permission strings, manifest
   entries, and native code part of the same change.

## 3. Handle the unhappy paths

A senior engineer's work stands out here. Check each item:

- Async gaps: check `mounted` after every `await` in a `State`. Disable buttons
  while busy (`_busy`), as `EditRecordPage` does, so double taps cannot submit
  twice.
- User-facing errors: catch `FormatException` and show its message. Catch
  everything else and show a calm, generic message in a SnackBar. Never show
  stack traces or raw exceptions to the user.
- Permission denied or picker cancelled: return quietly with no error. If the
  user permanently denied access, explain how to enable it in Settings.
- Storage: a failed write must clean up copied files, as `save()` does.
- Lifecycle: dispose `TextEditingController`s, `FocusNode`s, animation
  controllers, and subscriptions.
- Accessibility: provide `Semantics` labels for icon-only or custom-painted
  controls, make tap targets at least 48×48, and make sure layouts survive a
  1.3× text scale and dark mode.

## 4. Test it

- Unit tests for the parsing and formatting logic in the domain.
- Repository tests with `sqflite_common_ffi` against a temporary directory.
  Close and reopen the repository to prove the data persisted, and include an
  upgrade test for any migration.
- Widget tests for the main user flow at iPhone 16 size, using an in-memory
  `VaultRepository` fake (copy the pattern in `test/vault_flow_test.dart`).
  Drive the flow by `ValueKey` and assert on what the user sees.
- When a test is hard to write, treat it as a design smell. Move the logic out
  of the widget and into the controller or domain.

## 5. Verify and report

Run the `mobile-verify` skill. If the toolchain is available, launch the app on
an iOS simulator and look at the new screen in both light and dark mode.

Finish with a short report: what changed (by layer), the decisions you made and
why, the verification you ran (with its results), and anything you could not
verify along with why. For example, "Camera capture needs a physical iPhone."
