"""Run the iOS app against the web project's local Supabase environment."""

import argparse
from ipaddress import IPv4Address, IPv4Network
import os
from pathlib import Path
import sys
from urllib.parse import urlsplit, urlunsplit


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--lan-host", help="Mac's private IPv4 address for a physical iPhone")
options, flutter_args = parser.parse_known_args()

root = Path(__file__).resolve().parents[1]
env_path = root.parent / "paperdrawer-web" / ".env.development.local"
public_keys = {
    "NEXT_PUBLIC_SUPABASE_URL": "SUPABASE_URL",
    "NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY": "SUPABASE_PUBLISHABLE_KEY",
}
settings = {}
if not env_path.is_file():
    sys.exit(f"Missing {env_path}. Set up the web app's local Supabase environment.")
for line in env_path.read_text().splitlines():
    name, equals, value = line.partition("=")
    if equals and name.strip() in public_keys:
        settings[public_keys[name.strip()]] = value.strip().strip("'\"")
if any(not settings.get(key) for key in public_keys.values()):
    sys.exit("Set the Supabase URL and publishable key in the web development environment.")
api = urlsplit(settings["SUPABASE_URL"])
if api.hostname not in {"localhost", "127.0.0.1", "::1"}:
    sys.exit("The local launcher requires a Supabase URL on this Mac.")

settings["PAPERDRAWER_WEB_URL"] = "http://localhost:3000"
if options.lan_host:
    try:
        host = IPv4Address(options.lan_host)
    except ValueError:
        sys.exit("Pass your Mac's private IPv4 address to --lan-host.")
    private = ("10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16")
    if not any(host in IPv4Network(network) for network in private):
        sys.exit("Use your Mac's private IPv4 address on the same Wi-Fi network.")
    settings["SUPABASE_URL"] = urlunsplit(
        (api.scheme, f"{host}:{api.port or 54321}", api.path, "", "")
    )
    settings["PAPERDRAWER_WEB_URL"] = f"http://{host}:3000"
    # Local Supabase emails link back to the Mac's loopback web server.
    settings["PAPERDRAWER_CONFIRM_ORIGIN"] = "http://localhost:3000"

os.chdir(root)
defines = [f"--dart-define={key}={value}" for key, value in settings.items()]
os.execvp("flutter", ["flutter", "run", *defines, *flutter_args])
