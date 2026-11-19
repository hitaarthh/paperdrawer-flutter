# Run PaperDrawer on your iPhone

Use this runbook to install the shared-vault development build on your physical
iPhone. The Mac runs the web app and Docker Supabase. The iPhone uses the same
Supabase account, bills, documents and claims over Wi-Fi. USB is used to install
and launch the app.

## Rebuild and relaunch from Windows

Keep the Mac awake, its Paper Drawer services running, and the paired iPhone
connected to the Mac. On the Mac, enable **System Settings → General →
Sharing → Remote Login** for your Mac account and note the SSH address shown.
On Windows, use Python 3.9 or later and the OpenSSH Client.

Copy `tool/deploy_iphone.py` to Windows and run this from PowerShell. Use the
Mac's LAN IP if Windows can't resolve the `.local` name.

```powershell
py .\deploy_iphone.py --host hitarth@Hitarths-MacBook-Pro.local --check
py .\deploy_iphone.py --host hitarth@Hitarths-MacBook-Pro.local
```

The launcher builds the Mac checkout, installs Paper Drawer in place, and
relaunches it. Add `--update` to fast-forward a clean checkout from its
configured Git upstream before building. The default checkout is
`~/Projects/paperdrawer/paperdrawer-flutter` on the Mac. Supply
`--project-dir /absolute/mac/path` if you keep it elsewhere.

Run `python3 tool/deploy_iphone.py` from the Mac for the same workflow
without SSH. Add `--build-only` to verify the signed app without installing it.

## 1. Start the services on the Mac

Start Docker Desktop, then run these commands in Terminal:

```sh
cd /Users/hitarth/Projects/paperdrawer/paperdrawer-web
npm run db:start
npm run dev
```

Leave that tab open. The web app is at `http://localhost:3000`, Supabase is on
port `54321`, and local confirmation emails are at `http://localhost:54324`.
You can check whether the containers are already running in a separate tab:

```sh
docker ps --format '{{.Names}} {{.Ports}}'
curl -fsS -o /dev/null -w '%{http_code}\n' http://localhost:3000/signin
```

The second command should print `200` once Next.js is ready.

## 2. Pair and prepare the physical iPhone

1. Connect the iPhone over USB and unlock it. Tap **Trust** if it asks whether
   you trust this Mac.
2. On the phone, enable **Settings → Privacy & Security → Developer Mode**.
   Follow the reboot prompt, unlock the phone, and confirm **Turn On**.
3. Keep the phone unlocked and connected during the first install. Put the
   iPhone and Mac on the same Wi-Fi network.

Wireless deployment is also available after pairing when both devices are on the
same Wi-Fi network with IPv6 enabled. These steps were verified over USB.
[Apple’s device pairing guide](https://developer.apple.com/documentation/Xcode/managing-your-simulated-and-physical-devices-in-device-hub)

From Terminal, check the device and copy the ID for the row marked **physical**:

```sh
xcrun devicectl list devices
flutter devices
export PAPERDRAWER_IPHONE_ID='<paste the physical iPhone ID here>'
xcrun devicectl device info ddiServices --device "$PAPERDRAWER_IPHONE_ID"
```

`isUsable: true` means Xcode can use its developer services on the phone. When
the device showed `connected (no DDI)`, the detailed error said it was locked.
Unlocking it and rerunning the last command resolved that.

If you get a signing error, check for a development identity:

```sh
security find-identity -v -p codesigning
```

If signing needs setup, open the workspace, sign in to your Apple Account in
**Xcode → Settings → Apple Accounts**, then select your team under **Runner →
Signing & Capabilities**.

```sh
cd /Users/hitarth/Projects/paperdrawer/paperdrawer-flutter
open ios/Runner.xcworkspace
```

## 3. Build and install the shared-vault app

Use a new Terminal tab for Flutter. If you set the device ID in another tab,
set it again in this tab.

```sh
cd /Users/hitarth/Projects/paperdrawer/paperdrawer-flutter
flutter pub get
export PAPERDRAWER_LAN_HOST="$(ipconfig getifaddr en0)"
printf '%s\n' "$PAPERDRAWER_LAN_HOST"
python3 tool/run_shared_local.py --profile --lan-host "$PAPERDRAWER_LAN_HOST" -d "$PAPERDRAWER_IPHONE_ID" --no-resident
```

The launcher reads the two public Supabase settings from the web project's
`.env.development.local`. The LAN address lets the phone reach the Mac. A profile
build can be reopened from the Home Screen once installed.

### If Flutter builds the app but cannot find its output

On this Mac, Xcode built `build/ios/Profile-iphoneos/Runner.app` successfully
while Flutter looked for `build/ios/iphoneos/Runner.app`. If you see that error,
verify the build and install the actual output directly:

```sh
codesign --verify --deep build/ios/Profile-iphoneos/Runner.app
xcrun devicectl device install app --device "$PAPERDRAWER_IPHONE_ID" build/ios/Profile-iphoneos/Runner.app
xcrun devicectl device process launch --device "$PAPERDRAWER_IPHONE_ID" --terminate-existing app.paperdrawer.mobile
```

The install and launch commands above succeeded on the physical iPhone 16.

### Actions the first time you install

- **Developer support files are copying**. Keep the phone on USB while Xcode
  copies and extracts them. The first run can take several minutes.
- **Untrusted Developer**. On the iPhone, go to **Settings → General → VPN &
  Device Management → Developer App**. Select your own Apple Development
  certificate, tap **Trust**, and follow any restart prompt. Then open
  PaperDrawer again.
- **Flutter debug mode screen**. This appears when you open a debug build from
  the Home Screen. Reinstall the profile build above to open it from its icon.
  For live debug and hot reload, launch through Flutter.
- **Local Network permission**. Tap **Allow** when asked so the app can reach
  Supabase on the Mac. If sign-in cannot connect, check iPhone and Mac Wi-Fi and
  recheck the development URLs from the Mac:

```sh
curl -fsS -o /dev/null -w '%{http_code}\n' "http://$PAPERDRAWER_LAN_HOST:54321/auth/v1/health"
curl -fsS -o /dev/null -w '%{http_code}\n' "http://$PAPERDRAWER_LAN_HOST:3000/signin"
```

To confirm installation from Terminal:

```sh
xcrun devicectl device info apps --device "$PAPERDRAWER_IPHONE_ID" --bundle-id app.paperdrawer.mobile
```

If Flutter prints `Lost connection to device` after `Installing and launching`,
check whether the app is running directly on the iPhone:

```sh
xcrun devicectl device info processes --device "$PAPERDRAWER_IPHONE_ID" | rg 'Runner\.app/Runner'
```

A process with a path ending in `Runner.app/Runner` confirms the app is
running. Open **Paper Drawer** from the Home Screen to reopen the profile
build. If the process is absent, use the `devicectl device process launch`
command above.

## 4. Sign in and check the data

Clara’s account exists in the development Docker database.

| Email | Local seed password | Expected data |
| --- | --- | --- |
| `clara@paperdrawer.app` | `hashed_pwd_clara` | 6 bills, 4 documents, 4 claims |
| `paperdrawer-mobile-preview-20261119@example.com` | `paperdrawer-dev` | 6 bills, 4 documents, 4 claims |

These are local development accounts. Clara’s password comes from
`paperdrawer-web/supabase/seed.sql` and was checked against the local database.
The second account was created with the existing seed script:

```sh
cd /Users/hitarth/Projects/paperdrawer/paperdrawer-web
env -u SUPABASE_URL -u SUPABASE_SECRET_KEY npm run seed:user -- --email paperdrawer-mobile-preview-20261119@example.com --name 'Mobile Preview' --timezone Asia/Kolkata
```

1. Open **PaperDrawer** on the phone and sign in.
2. Check the **Vault** and **Claims** tabs. Open a bill and tap an original.
3. Use **Open on web** to make edits. Return to the phone and tap refresh to
   see changes from the web.
4. To test **Create an account**, use a new test email. On the Mac, open
   `http://localhost:54324` and follow the confirmation link. Return to the
   phone and sign in.

## Simulator and Xcode commands used earlier

The simulator is a separate destination. If you need it later, choose the
simulated iPhone from `xcrun simctl list devices available`:

```sh
cd /Users/hitarth/Projects/paperdrawer/paperdrawer-flutter
xcrun simctl list devices available
export PAPERDRAWER_SIMULATOR_ID='<paste the simulator ID here>'
xcrun simctl bootstatus "$PAPERDRAWER_SIMULATOR_ID" -b
open /Applications/Xcode.app/Contents/Applications/DeviceHub.app
flutter run -d "$PAPERDRAWER_SIMULATOR_ID"
```

On Xcode 27, select the matching simulator in **Device Hub**. The older
`open -a Simulator` command failed on this installation. To open the shared
vault with local accounts on a simulator, use:

```sh
python3 tool/run_shared_local.py -d "$PAPERDRAWER_SIMULATOR_ID"
```

The earlier Xcode GUI path used the following commands:

```sh
flutter build ios --simulator --debug --config-only
open ios/Runner.xcworkspace
```

If Xcode reports that Swift packages are already open from another workspace,
quit Xcode completely with **⌘Q**, then open only `Runner.xcworkspace`. The
Terminal launch succeeded when the Xcode GUI showed a missing
`FlutterGeneratedPluginSwiftPackage` product.

## Verification from this session

```sh
dart format lib test
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
flutter build ios --simulator --debug --no-pub
git diff --check
```

The analyzer and simulator build passed. Twelve tests passed in the verification
copy, including a local Docker integration check for signing in, reading the
seeded vault, and fetching a private original. The email-signup check also
passed against the local inbox and web confirmation callback. Apple’s device
tool confirmed that the profile build installed and launched on the real iPhone.

### November 19, 2026 screen update

This update used the existing Docker and Next.js services and the physical
iPhone 16. After confirming the developer disk image and local endpoints, the
updated source passed the analyzer and 72 tests. The suite included capture and
review with fake camera and OCR services, Bill Detail at 130% text scale, the
SQLite upgrade, and read access to the local shared vault.

```sh
xcrun devicectl device info ddiServices --device "$PAPERDRAWER_IPHONE_ID"
curl -fsS -o /dev/null http://127.0.0.1:54321/auth/v1/health
curl -fsS -o /dev/null http://127.0.0.1:3000/signin
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
export PAPERDRAWER_LAN_HOST="$(ipconfig getifaddr en0)"
python3 tool/run_shared_local.py --profile --lan-host "$PAPERDRAWER_LAN_HOST" -d "$PAPERDRAWER_IPHONE_ID" --no-pub --no-resident
xcrun devicectl device info apps --device "$PAPERDRAWER_IPHONE_ID" --bundle-id app.paperdrawer.mobile
xcrun devicectl device info processes --device "$PAPERDRAWER_IPHONE_ID" | rg 'Runner\.app/Runner'
```

The `--no-pub` commands use the dependencies already installed in the build
copy. Run `flutter pub get` before them if you are starting from a fresh copy.
Xcode built the tested snapshot in profile mode. The device commands confirmed
that the updated app installed and its process was running on the iPhone.

The updated shared-vault Add flow uses the iPhone camera, Photos and Files, or
manual entry. Check the details and tap **Save to vault** to save the new
record and its original to the same Supabase vault. A local development build
still needs the Mac's Supabase service to save.
