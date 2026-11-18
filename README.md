# PaperDrawer Mobile

PaperDrawer for iPhone, built in Flutter. The first release is a private, on-device
vault for receipts, policies, and documents. Android project files are included
for the next platform pass.

## Run it

Use Flutter 3.50 or later, Xcode, and an installed iOS Simulator runtime.

```sh
flutter pub get
flutter devices
flutter run -d <iphone-simulator-id>
```

Camera capture needs a physical iPhone. The Photos and Files import flows can be
used on a simulator with sample images and PDFs. The format limits are shown by
the picker and checked when the record is saved.

```sh
flutter analyze
flutter test
```

## How the pieces fit

- `lib/src/ui` contains the shared shell and page layout, the vault list, the
  add/edit form, document details, and settings.
- `lib/src/theme` contains light and dark palettes and the shared type styles.
  The asset folder holds the launcher icon, bundled fonts, and their licenses.
- `VaultController` exposes the current vault snapshot and uses Flutter's
  ChangeNotifier through Provider. It serializes writes, refreshes after saving,
  and keeps views up to date.
- `VaultRepository` is the storage boundary. The SQLite implementation stores
  metadata and appearance settings. Imported originals live under private
  Application Support with relative paths, outside temporary picker storage.
  Archived records retain their originals and can be restored.
- On iOS, the application-created vault directory is excluded from device
  backups. The app uses no sign-in, network backend, analytics, or cloud sync.
  Uninstalling can remove the entire vault.

The first pass includes manual entry and deadline dates. Receipt OCR, scheduled
reminders, and cloud storage are future features.
