#!/usr/bin/env bash
set -euo pipefail

CONFIG="$HOME/.config/quickshell/data/config.json"

backend=$(python3 << 'PYEOF'
import json, sys, os
try:
    with open(os.path.expanduser("~/.config/quickshell/data/config.json")) as f:
        d = json.load(f)
    ws = d.get("components", {}).get("wallpaperSelector", {})
    if isinstance(ws, dict):
        print(ws.get("backend", "quickshell"))
    else:
        print("quickshell" if ws else "rofi")
except Exception as e:
    print("quickshell")
PYEOF
)

if [[ "$backend" == "rofi" ]]; then
    bash "$HOME/.config/hypr/UserScripts/WallpaperSelect.sh"
else
    if pgrep -x quickshell >/dev/null; then
        qs ipc call wallpaperpicker open
    else
        quickshell >/dev/null 2>&1 &
        sleep 0.6
        qs ipc call wallpaperpicker open
    fi
fi
