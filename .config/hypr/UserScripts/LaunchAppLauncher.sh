#!/usr/bin/env bash
set -euo pipefail

CONFIG="$HOME/.config/quickshell/data/config.json"

backend=$(python3 << 'PYEOF'
import json, sys, os
try:
    with open(os.path.expanduser("~/.config/quickshell/data/config.json")) as f:
        d = json.load(f)
    al = d.get("components", {}).get("appLauncher", True)
    if isinstance(al, dict):
        print(al.get("backend", "quickshell"))
    else:
        print("quickshell" if al else "rofi")
except Exception as e:
    print("quickshell")
PYEOF
)

if [[ "$backend" == "rofi" ]]; then
    rofi -show drun
else
    if pgrep -x quickshell >/dev/null; then
        qs ipc call applauncher toggle
    else
        quickshell >/dev/null 2>&1 &
        sleep 0.6
        qs ipc call applauncher toggle
    fi
fi
