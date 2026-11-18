---
name: mobile-platform-integration
description: How to wire Flutter plugins and native platform features into PaperDrawer correctly on iOS and Android, covering permissions and usage strings, camera, photos, files, local notifications and reminders, the share sheet, URL launching, method channels, and app config such as the bundle ID, deployment targets, and Info.plist or AndroidManifest. Use when adding or changing anything that touches native code, permissions, or plugin setup.
---

# Platform integration for PaperDrawer

## Project facts

- iOS bundle ID: `app.paperdrawer.mobile`. Deployment target: iOS 15.0. The
  app uses `FlutterImplicitEngineDelegate` in `ios/Runner/AppDelegate.swift`.
- Android `applicationId`: `app.paperdrawer.mobile` (namespace
  `app.paperdrawer.paperdrawer`), with `minSdk = flutter.minSdkVersion`.
  Android is the next platform pass, so keep it compiling but put iOS first.
- Existing native channel: `app.paperdrawer.mobile/storage` with the method
  `excludeFromBackup`. New channels follow `app.paperdrawer.mobile/<area>`.
  Native errors return a `FlutterError` with a snake_case `code` and a
  user-safe `message`.
- Existing iOS usage strings cover `NSCameraUsageDescription` and
  `NSPhotoLibraryUsageDescription`.

## Rules

1. **Configure in the same change.** When you start using a plugin, add every
   Info.plist key, AndroidManifest permission, entitlement, and Gradle or
   Podfile setting its README requires, in the same change. Check the
   plugin's current README for the version pinned in `pubspec.lock`. Do not
   rely on memory.
2. **Ask for permission in context.** Request a permission only when the user
   takes the action that needs it, never at launch. Handle the denied,
   permanently denied, and restricted outcomes. When access is permanently
   denied, explain the situation and offer to open Settings.
3. **Usage strings** explain the benefit to the user in a single sentence, in
   PaperDrawer's voice, for example "Take a photo of a receipt or document to
   keep in your vault."
4. **Keep it local.** No plugin may add network analytics, crash reporting, or
   ad identifiers. If a plugin brings any of these, flag it to the user before
   you adopt it.
5. **Keep native code small.** Keep logic in Dart. Native code does only what
   Dart cannot do, and its handler returns `FlutterMethodNotImplemented` for
   unknown methods.

## Feature notes

- **Camera and photos** (`image_picker`, `camera`): `image_picker` is already
  used in `EditRecordPage`. Treat a `null` result as a cancel. Camera capture
  needs a physical device, so say so when you report your verification. Reach
  for `camera` only when you need a custom capture UI, such as document edge
  guides.
- **Files** (`file_selector`): restrict the picker to the
  `attachmentExtensions` types. Re-validate the size and extension in the
  repository anyway.
- **Reminders** (`flutter_local_notifications`, `timezone`,
  `flutter_timezone`): call `tz.initializeTimeZones()`, set the local location
  from `FlutterTimezone.getLocalTimezone()`, and schedule with
  `zonedSchedule`. A deadline is a civil date, so schedule it at a fixed local
  time, such as 9:00 on the day or N days before. Derive notification IDs
  deterministically from the record ID, so that editing or archiving a record
  can cancel or replace its reminder. Request notification permission when the
  user first turns a reminder on. On Android, declare `POST_NOTIFICATIONS`
  (API 33+) and decide whether exact alarms are needed. The default answer is
  no, and inexact delivery is fine.
- **Share and export** (`share_plus`, `archive`): on iPad, pass
  `sharePositionOrigin` from the button's render box, or the share sheet
  crashes. Delete the temporary export after sharing.
- **Opening originals** (`open_filex`, `url_launcher`): check the result type
  and show a SnackBar on failure.
- **Version display** (`package_info_plus`): show it in Settings, read once.

## Verification

- `flutter build ios --simulator --debug` must succeed after any iOS change.
  Run `cd ios && pod install` only when a plugin changes the Pods.
- After an Android change, also run `flutter build apk --debug`.
- For permission flows, test on a simulator: reset with
  `xcrun simctl privacy <device> reset all app.paperdrawer.mobile`, then
  exercise the grant, deny, and re-prompt paths.
- Report anything that needs a physical device: the camera, notification
  delivery while locked, and real Files providers.
