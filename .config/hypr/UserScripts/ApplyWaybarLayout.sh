#!/usr/bin/env bash
set -euo pipefail

CONFIG="$HOME/.config/quickshell/data/config.json"
WAYBAR_CONFIG="$HOME/.config/waybar/configs/[TOP] Default"

python3 << 'PYEOF'
import re, json, sys, os

config_path = os.path.expanduser("~/.config/quickshell/data/config.json")
waybar_path = os.path.expanduser("~/.config/waybar/configs/[TOP] Default")

# Read QS config
with open(config_path) as f:
    cfg = json.load(f)

bar = cfg.get("components", {}).get("bar", {})
top_panel  = bar.get("topPanel", True)
dashboard  = bar.get("dashboard", True)

# Read waybar config, stripping // comments for JSON parsing
with open(waybar_path) as f:
    raw = f.read()

stripped = re.sub(r'//[^\n]*', '', raw)
bars = json.loads(stripped)

for bar_cfg in bars:
    output = bar_cfg.get("output", "")

    # -- modules-center: topPanel toggle --
    if "modules-center" in bar_cfg:
        mc = bar_cfg["modules-center"]
        has_top = "custom/qs_dashboard_top" in mc
        if top_panel and not has_top:
            # Insert before "clock" if present, else append
            idx = mc.index("clock") if "clock" in mc else len(mc)
            mc.insert(idx, "custom/qs_dashboard_top")
        elif not top_panel and has_top:
            mc.remove("custom/qs_dashboard_top")

    # -- modules-right: dashboard toggle --
    if "modules-right" in bar_cfg:
        mr = bar_cfg["modules-right"]
        has_dash   = "custom/qs_dashboard"  in mr
        has_power  = "custom/power_button"  in mr
        if dashboard:
            # Want qs_dashboard
            if has_power:
                mr[mr.index("custom/power_button")] = "custom/qs_dashboard"
            elif not has_dash:
                mr.append("custom/qs_dashboard")
        else:
            # Want power_button
            if has_dash:
                mr[mr.index("custom/qs_dashboard")] = "custom/power_button"
            elif not has_power:
                mr.append("custom/power_button")

# Write back - re-inject the original comment header manually
header_match = re.match(r'(//[^\n]*\n)', raw)
header = header_match.group(1) if header_match else ""
with open(waybar_path, "w") as f:
    f.write(header + json.dumps(bars, indent=2) + "\n")

PYEOF

# Restart waybar to apply changes
pkill waybar 2>/dev/null || true
sleep 0.3
nohup waybar > /dev/null 2>&1 &
