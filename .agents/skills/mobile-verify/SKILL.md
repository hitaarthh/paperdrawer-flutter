---
name: mobile-verify
description: Verification routine for the PaperDrawer Flutter app, covering format, analyze, and test runs, iOS and Android builds, launching on the iOS simulator, screenshots, and an honest final report. Use before saying any PaperDrawer change is done, when asked to run or check the app, or after resolving merge conflicts or upgrading dependencies.
---

# Verifying a PaperDrawer change

Run the checks from the repo root (`paperdrawer-flutter/`). Fix every failure
before you report, and never report a check as passed if you did not run it.

## 1. Static checks and tests (always)

```sh
dart format lib test
flutter analyze                 # expect: No issues found!
flutter test                    # expect: All tests passed!
```

- Do not silence a lint with `// ignore:` unless you can name the reason in the
  comment.
- If a test fails, read the failure and fix the code, or fix the test if the
  behaviour changed on purpose. Do not delete or skip tests to make the run go
  green.
- After a dependency change, run `flutter pub get` first and check that
  `pubspec.lock` changed only as you expected.

## 2. Builds (whenever native code, plugins, or assets changed)

```sh
flutter build ios --simulator --debug
flutter build apk --debug        # once Android is in scope, or if you touched android/
```

## 3. See it running (UI changes, when a simulator is available)

```sh
xcrun simctl list devices available | grep -i iphone
xcrun simctl boot "iPhone 16" 2>/dev/null; open -a Simulator
flutter run -d "iPhone 16"
```

- Capture with `xcrun simctl io booted screenshot <scratch>/screen.png`. The
  app is dark-only at launch. If a light theme exists later, switch with
  `xcrun simctl ui booted appearance light` and check both.
- Check the result against `design/` and against the
  `paperdrawer-design-system` skill. Look for overflow stripes, clipped text,
  and contrast problems.
- Try a larger text size with
  `xcrun simctl ui booted content_size extra-extra-large`.
- Save screenshots outside the repo, unless the user asks for them under
  `design/`.

If no simulator or Xcode runtime is available, say so. Widget tests at iPhone
16 size are the fallback, not an equivalent.

## 4. Report

End with a short report in this shape:

```
Changed: <layers/files, one line each>
Verified: format ✓  analyze ✓  test ✓ (N passed)  ios build ✓  simulator ✓
Not verified: <e.g. camera capture — needs physical iPhone>
Follow-ups: <only real ones>
```
