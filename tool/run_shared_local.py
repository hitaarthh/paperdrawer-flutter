"""Run the iOS app against the web project's local Supabase environment."""

import os
from pathlib import Path
import sys
from urllib.parse import urlsplit


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
if urlsplit(settings["SUPABASE_URL"]).hostname not in {"localhost", "127.0.0.1", "::1"}:
    sys.exit("The local launcher requires a Supabase URL on this Mac.")

settings["PAPERDRAWER_WEB_URL"] = "http://localhost:3000"
os.chdir(root)
defines = [f"--dart-define={key}={value}" for key, value in settings.items()]
os.execvp("flutter", ["flutter", "run", *defines, *sys.argv[1:]])
