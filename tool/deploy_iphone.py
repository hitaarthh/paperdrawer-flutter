"""Build and relaunch Paper Drawer on a paired iPhone, locally or over SSH."""

import argparse
import json
import os
from pathlib import Path
import plistlib
import shlex
import shutil
import subprocess
import sys
import tempfile
from urllib.error import URLError
from urllib.request import urlopen


BUNDLE_ID = "app.paperdrawer.mobile"
SCRIPT = "tool/deploy_iphone.py"


def run(*command, capture=False):
    return subprocess.run(
        command, check=True, text=True, stdout=subprocess.PIPE if capture else None
    ).stdout


def run_remotely(options):
    if not shutil.which("ssh"):
        raise RuntimeError("Install the Windows OpenSSH Client and try again.")
    project = (
        shlex.quote(options.project_dir)
        if options.project_dir
        else '"$HOME/Projects/paperdrawer/paperdrawer-flutter"'
    )
    arguments = ["python3", "-u", SCRIPT]
    for flag, enabled in (
        ("--update", options.update),
        ("--check", options.check),
        ("--build-only", options.build_only),
    ):
        if enabled:
            arguments.append(flag)
    if options.device:
        arguments.extend(["--device", options.device])
    if options.lan_host:
        arguments.extend(["--lan-host", options.lan_host])
    command = f"cd {project} && exec {shlex.join(arguments)}"
    return subprocess.call(
        ["ssh", "-o", "ConnectTimeout=10", "--", options.host, command]
    )


def device_json(*command):
    with tempfile.TemporaryDirectory(prefix="paperdrawer-device-") as directory:
        output = Path(directory) / "result.json"
        run("xcrun", "devicectl", *command, "--quiet", "--json-output", str(output))
        return json.loads(output.read_text(encoding="utf-8"))["result"]


def paired_iphone(requested):
    phones = []
    for device in device_json("list", "devices")["devices"]:
        hardware = device["hardwareProperties"]
        connection = device["connectionProperties"]
        if (
            hardware["reality"] == "physical"
            and hardware["deviceType"] == "iPhone"
            and connection["pairingState"] == "paired"
            and connection["tunnelState"] == "connected"
        ):
            if requested and requested not in (hardware["udid"], device["identifier"]):
                continue
            phones.append((device["deviceProperties"]["name"], hardware["udid"]))

    if not phones:
        raise RuntimeError("Connect and unlock your paired iPhone, then try again.")
    if len(phones) != 1:
        choices = "\n".join(f"  {name}  {udid}" for name, udid in phones)
        raise RuntimeError(f"More than one iPhone is connected. Use --device.\n{choices}")

    name, udid = phones[0]
    if not device_json("device", "info", "ddiServices", "--device", udid)[
        "ddiMetadata"
    ]["isUsable"]:
        raise RuntimeError("Xcode developer services are unavailable. Unlock your iPhone and check Developer Mode.")
    print(f"Using {name}", flush=True)
    return udid


def check_local_services(host):
    for service, url in (
        ("Supabase", f"http://{host}:54321/auth/v1/health"),
        ("the Paper Drawer web app", f"http://{host}:3000/signin"),
    ):
        try:
            with urlopen(url, timeout=5):
                pass
        except (URLError, TimeoutError):
            raise RuntimeError(
                f"The Mac couldn't reach {service}. Check the local Paper Drawer "
                "services and Mac Wi-Fi before deploying."
            ) from None


def deploy(options):
    import fcntl

    project = (
        Path(options.project_dir).expanduser()
        if options.project_dir
        else Path(__file__).resolve().parents[1]
    )
    os.chdir(project)
    if not Path("tool/run_shared_local.py").is_file() or not Path("pubspec.yaml").is_file():
        raise RuntimeError("Set --project-dir to the Paper Drawer Flutter checkout on the Mac.")

    # Noninteractive SSH sessions do not load the usual Homebrew shell profile.
    os.environ["PATH"] += ":/opt/homebrew/bin:/usr/local/bin"
    if not shutil.which("flutter"):
        raise RuntimeError("Flutter is missing from the Mac's PATH.")

    host = options.lan_host
    if not host:
        host = subprocess.run(
            ["ipconfig", "getifaddr", "en0"], text=True, capture_output=True
        ).stdout.strip()
    if not host:
        raise RuntimeError("The Mac has no Wi-Fi IPv4 address. Supply it with --lan-host.")
    check_local_services(host)
    device = None if options.build_only else paired_iphone(options.device)
    if options.check:
        print("Ready. The Mac can reach the local services and your iPhone.")
        return

    lock_path = Path(".dart_tool/paperdrawer-deploy.lock")
    lock_path.parent.mkdir(exist_ok=True)
    with lock_path.open("a") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise RuntimeError("A Paper Drawer deployment is already running.") from None

        if options.update:
            if run("git", "status", "--porcelain", capture=True):
                raise RuntimeError("The Mac checkout has local changes. Run without --update to build those changes.")
            run("git", "pull", "--ff-only")

        print("Building the shared-vault iPhone profile…", flush=True)
        run(sys.executable, "tool/run_shared_local.py", "--lan-host", host, "--build-only", "--profile")
        app = next(
            (
                path
                for path in (
                    Path("build/ios/iphoneos/Runner.app"),
                    Path("build/ios/Profile-iphoneos/Runner.app"),
                )
                if (path / "Info.plist").is_file()
            ),
            None,
        )
        if app is None:
            raise RuntimeError("The build finished, but Xcode's Runner.app could not be found.")
        with (app / "Info.plist").open("rb") as plist:
            if plistlib.load(plist).get("CFBundleIdentifier") != BUNDLE_ID:
                raise RuntimeError("Xcode produced an unexpected app bundle identifier.")
        run("codesign", "--verify", "--deep", "--strict", str(app))
        if options.build_only:
            print(f"Verified signed build at {app}.")
            return

        print("Updating Paper Drawer on the iPhone…", flush=True)
        run("xcrun", "devicectl", "device", "install", "app", "--device", device, str(app))
        run(
            "xcrun", "devicectl", "device", "process", "launch", "--device", device,
            "--terminate-existing", BUNDLE_ID,
        )
        print("Paper Drawer is running. Open the Claims tab to check the build.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", help="Mac SSH destination, for example user@mac.local")
    parser.add_argument("--project-dir", help="Absolute path of the Flutter checkout on the Mac")
    parser.add_argument("--device", help="iPhone UDID when more than one is paired and connected")
    parser.add_argument("--lan-host", help="Override automatic detection of the Mac's Wi-Fi IPv4")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--check", action="store_true", help="Check connectivity without building or installing")
    mode.add_argument("--build-only", action="store_true", help="Verify a signed build without installing")
    parser.add_argument("--update", action="store_true", help="Fast-forward a clean Mac checkout before building")
    options = parser.parse_args()
    if options.check and options.update:
        parser.error("--check cannot be used with --update")
    if not options.host and sys.platform != "darwin":
        parser.error("Pass --host user@mac.local to build from this computer.")
    try:
        if options.host:
            return run_remotely(options)
        deploy(options)
        return 0
    except (OSError, RuntimeError, ValueError) as error:
        print(f"Paper Drawer deployment stopped. {error}", file=sys.stderr)
        return 1
    except subprocess.CalledProcessError as error:
        print(f"Paper Drawer deployment stopped at {error.cmd[0]} (exit {error.returncode}).", file=sys.stderr)
        return error.returncode


if __name__ == "__main__":
    sys.exit(main())
