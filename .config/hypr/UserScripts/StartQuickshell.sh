#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="$HOME/.config/skwd-wall/.env"
CONFIG="$HOME/.config/quickshell/data/config.json"

# Source .env if present
if [[ -f "$ENV_FILE" ]]; then
    set -a
    source "$ENV_FILE"
    set +a
fi

# Check if any QS component actually needs quickshell running
needs_qs=$(python3 << 'PYEOF'
import json, sys, os
try:
    with open(os.path.expanduser("~/.config/quickshell/data/config.json")) as f:
        d = json.load(f)
    c = d.get("components", {})
    bar = c.get("bar", {})

    def launcher_needs_qs(val, key):
        if isinstance(val, bool):
            return val          # legacy boolean = QS
        if isinstance(val, dict):
            return val.get("enabled", True) and val.get("backend", "quickshell") == "quickshell"
        return True  # default safe

    checks = [
        launcher_needs_qs(c.get("appLauncher", True), "appLauncher"),
        launcher_needs_qs(c.get("wallpaperSelector", True), "wallpaperSelector"),
        bool(c.get("windowSwitcher", True)),
        c.get("powerMenu", {}).get("enabled", True) if isinstance(c.get("powerMenu"), dict) else bool(c.get("powerMenu", True)),
        bool(c.get("notifications", True)),
        bool(bar.get("topPanel", True)),
        bool(bar.get("dashboard", True)),
    ]
    print("yes" if any(checks) else "no")
except Exception as e:
    print("yes")  # safe fallback: always start QS if config unreadable
PYEOF
)

if [[ "$needs_qs" == "no" ]]; then
    echo "StartQuickshell: all components use non-QS backends, skipping QS start."
    exit 0
fi

exec qs
