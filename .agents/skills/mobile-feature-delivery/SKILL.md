---
name: mobile-feature-delivery
description: End-to-end senior mobile engineering workflow for adding a feature, screen, or flow to the PaperDrawer Flutter app, from understanding the request through domain rules, data, view models, UI, platform setup, tests, and verification. Use when asked to add, build, create, implement, or extend anything user-facing in PaperDrawer (for example items, cover windows, claims and ladders, reminders, scanning, sharing, export, search, plans, or new screens).
---

# Delivering a mobile feature in PaperDrawer

Work like a senior mobile engineer. Understand the request before you write
code, change each layer of the app in order, handle the unhappy paths, and
prove that the result works. Read `AGENTS.md` at the repo root first, then the
sections of `ARCHITECTURE.md` you will touch. Both override anything here. Then read the code you
are about to change. The code is the source of truth.

## 1. Frame the change (before you write code)

Write a short plan for yourself, and share it with the user when the change is
large or ambiguous:

- **User outcome.** In one sentence, what can the user do afterwards?
- **Layers touched.** Mark each one yes or no: domain models and rules
  (`lib/domain`), repository or service (`lib/data`), schema migration, view
  model, UI (`lib/ui/features/<feature>`), shared widgets (`lib/ui/core`), native or
  platform config, tests.
- **States.** List the empty, loading, success, and error states. Cover 0
  items, 1 item, a Base plan near or at its limit, and very long names. For
  dated features, check the edges: due today, due within `dueWithinDays`,
  expired yesterday, month-end and leap-day maths.
- **Platform impact.** Note any permission prompts, Info.plist or
  AndroidManifest changes, background behaviour, and whether the feature needs
  a physical device.
- **Privacy check.** Does anything leave the device, or does PaperDrawer act
  on the user's behalf? If so, stop and confirm with the user. See the product
  principles in `AGENTS.md`.
- **Smallest shippable slice.** Name it. Build that slice completely before you
  add anything else.

Ask the user only about decisions that are genuinely theirs to make, such as
product behaviour, plan limits, or copy that changes meaning. Decide the
conventional engineering choices yourself, and say what you chose.

## 2. Build from the bottom up

Change one layer at a time, and keep `flutter analyze` clean as you go.

1. **Domain (`lib/domain`).** Put models and business rules here, as pure Dart
   with immutable types. Examples are status calculations, cover windows, plan
   limits, and ladder progression. Reuse `formats.dart` for date and money
   maths. Write the unit tests now, since the logic is easiest to test here.
2. **Data (`lib/data`).** Define a repository interface first, then the
   implementation. Any schema change follows the `paperdrawer-local-data`
   skill. Services wrap a plugin (notifications, files, sharing) behind a small
   interface, so view models can be tested with fakes.
3. **View model or controller.** It holds screen state, exposes intent methods
   (`save`, `archive`, `escalate`), serializes writes, and catches errors from
   the layer below to turn them into user-facing state. Expose derived data as
   getters. Widgets should not compute it.
4. **UI (`lib/ui/features/<feature>`).** Follow the `paperdrawer-design-system` skill.
   Reuse the kit in `lib/ui/core/widgets/`, follow the screen recipe in
   `design/mobile-system/screens.md`, add routes in `lib/routing/router.dart`,
   and use only `Pd` and `PdType` for styling. Give every interactive element tests use a `ValueKey`.
   Handle every state you listed in step 1.
5. **Platform.** For any plugin or native work, follow the
   `mobile-platform-integration` skill. Make the permission strings, manifest
   entries, and native code part of the same change.

## 3. Handle the unhappy paths

A senior engineer's work stands out here. Check each item:

- Async gaps: check `mounted` after every `await` in a `State`. Disable the
  action while it is busy, so double taps cannot submit twice.
- User-facing errors: show validation messages inline. Catch unexpected
  failures and show a calm, generic message. Never show stack traces or raw
  exceptions to the user.
- Permission denied or picker cancelled: return quietly with no error. If the
  user permanently denied access, explain how to enable it in Settings.
- Storage: a failed write must leave no orphaned files and no partial rows.
  Use transactions, and clean up copied files.
- Time: "today" is the user's local civil date. Do not compare an instant with
  a civil date.
- Lifecycle: dispose `TextEditingController`s, `FocusNode`s, animation
  controllers, and subscriptions.
- Accessibility: give custom papers and stamps `Semantics` labels, make tap
  targets at least `Pd.tapMin`, and make sure layouts survive a 1.3× text
  scale.

## 4. Test it

- Unit tests for the domain rules, including the date edges listed in step 1.
- Repository tests with `sqflite_common_ffi` against a temporary directory.
  Close and reopen the repository to prove the data persisted, and include an
  upgrade test for any migration.
- Widget tests for the main user flow at iPhone 16 size, using in-memory fakes
  for repositories and services. Drive the flow by `ValueKey`, and assert on
  what the user sees. The archived `test/vault_flow_test.dart` shows the
  device setup.
- When a test is hard to write, treat it as a design smell. Move the logic out
  of the widget.

## 5. Verify and report

Run the `mobile-verify` skill. If the toolchain is available, launch the app on
an iOS simulator and look at the new screen. If you changed a contract, route,
schema, or kit component, update `ARCHITECTURE.md`.

Finish with a short report: what changed (by layer), the decisions you made and
why, the verification you ran (with its results), and anything you could not
verify along with why.
