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

## Account build development

See the [iPhone runbook](IOS_DEVICE_RUNBOOK.md) for pairing, installation,
local test accounts, and the Xcode errors encountered during setup.

The mobile app uses Supabase for accounts and shared settings. Start the web
project's Docker-backed Supabase and Next.js server in separate terminals from
`paperdrawer-web/`:

```sh
npm run db:start
npm run dev
```

Then, from `paperdrawer-flutter/`, run the app with the web project's local
publishable configuration. Choose the iOS simulator when prompted:

```sh
python3 tool/run_shared_local.py
```

For a physical iPhone, pair it over USB, enable Developer Mode, and put the Mac
and iPhone on the same Wi-Fi network. Pass the Mac’s Wi-Fi address so the iPhone
can reach the Docker services:

```sh
flutter devices
python3 tool/run_shared_local.py --profile --lan-host "$(ipconfig getifaddr en0)" -d <iphone-id>
```

The profile build can also be opened from the Home Screen. Allow local network
access if the iPhone asks. Use the local demo account with the development
server. Open local confirmation emails on the Mac.

Sign in with your local web account or create one in the app. Local confirmation
emails appear at `http://localhost:54324`. Confirm in the browser, then sign in
on the phone. Add a file, turn on airplane mode, and reopen the app to test
offline use. Sign out locally, reconnect, and sign in as a second user to
verify that each account opens its own drawer. The standard `flutter run`
launch opens the older device-only drawer while it remains unassigned.

For a hosted build, supply `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, and
optionally `PAPERDRAWER_WEB_URL` as Dart defines. The backend must allow the web
origin's `/auth/confirm` URL as a redirect. The app accepts Supabase publishable
and legacy anon keys. It uses the same owner-level policies as the web app.

Use a separate build configuration for local development, staging, and
production. In CI, pass the intended project's URL and publishable key as
explicit `--dart-define` arguments. These values are compiled into the app and
can be read from a distributed build. The authenticated session is stored in
the iOS Keychain. Keep Supabase secret or service-role keys, database passwords,
and SMTP credentials in the server environment. The local launcher reads only
the two named public values from the web project's development configuration.

## Checks

```sh
flutter analyze
flutter test
```

## How the pieces fit

- `lib/ui/features` contains the vault, add and edit forms, claims, settings,
  and account screens.
- `lib/ui/core/theme` contains the dark palette and shared type styles.
  The asset folder holds the launcher icon, bundled fonts, and their licenses.
- `ItemRepository` is the storage boundary for the device-only vault. The
  SQLite implementation stores metadata and settings. Originals live under private
  Application Support with relative paths, outside temporary picker storage.
  Archived records retain their originals and can be restored.
- On iOS, the vault directory is excluded from system backups. Exporting from
  Your data provides a copy of the records and originals. Signing in on a new
  phone restores shared settings and starts a new local drawer.
