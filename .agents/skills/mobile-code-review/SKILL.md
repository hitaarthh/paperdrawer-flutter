---
name: mobile-code-review
description: Senior mobile engineer review checklist for PaperDrawer Flutter changes, covering correctness, data safety, lifecycle and async bugs, platform permissions, privacy, performance, accessibility, and tests. Use when asked to review a diff, PR, or branch, or as a self-review before handing off a feature.
---

# Reviewing a PaperDrawer change

Review the diff (`git diff`, or `git diff main...HEAD`) against `AGENTS.md`.
Report findings ranked by severity. For each one, give `file:line`, what goes
wrong, a concrete case that triggers it, and the fix. Do not pad the list with
style nits that the analyzer or formatter already catches.

## Severity order

1. **Data loss or corruption.** Watch for a schema change without a working
   `onUpgrade` and a test. Watch for a dropped or recreated table, an absolute
   path persisted to the database, an attachment deleted before the database
   commit, files orphaned when a write fails, and writes that skip
   `VaultController._enqueue`.
2. **Privacy.** Look for any network call, analytics or crash SDK, logging of
   user content, files written outside `paperdrawer/` (and so outside the
   backup exclusion), or exports that leave plaintext behind.
3. **Crashes and correctness.** Look for `context` or `setState` used after an
   `await` without checking `mounted`, `!` on a value that can be null from the
   database or a picker, a missing iPad `sharePositionOrigin`, a missing
   Info.plist usage string (which crashes iOS immediately), unhandled
   permission denial, and time zone mistakes, such as treating a civil date as
   an instant or scheduling reminders in UTC.
4. **Lifecycle and leaks.** Check for undisposed controllers, focus nodes,
   streams, and listeners, `ChangeNotifier`s created inside `build`, and work
   started in `build`.
5. **Performance.** Check for whole-tree rebuilds from a broad `context.watch`
   where a `Selector` would do, large lists without `ListView.builder`,
   synchronous file or image work on the UI isolate, and a `CustomPainter`
   whose `shouldRepaint` always returns true.
6. **UX and accessibility.** Check for hard-coded colours instead of
   `context.palette`, text overflow at a 1.3× scale, a missing `Semantics` on
   custom controls, tap targets under 48pt, colour used as the only signal,
   dark mode left unchecked, and copy that is vague or blames the user.
7. **Tests.** Check that new behaviour is covered at the right level (domain
   unit, repository with reopen, widget flow), that tests assert on what the
   user sees, and that fakes are updated for any interface change.
8. **Maintainability.** Check for logic in widgets that belongs in the
   controller or domain, duplication of existing primitives in `design.dart`,
   files growing past roughly 400 lines, and a mix of `Navigator` and
   `go_router` styles.

## Before you hand off

Verify each finding by reading the surrounding code. Drop anything you cannot
tie to a concrete failure. If the review is a self-review, fix the findings and
then run the `mobile-verify` skill.
