#!/bin/bash
TEMPLATE="$HOME/.config/waybar/configs/[TOP] Default"
RUNTIME="/tmp/waybar-config-runtime.json"

# Wait for hyprctl to be ready (monitors may not be detected immediately at startup)
for i in $(seq 1 10); do
    MONITORS_JSON=$(hyprctl monitors -j 2>/dev/null)
    [ -n "$MONITORS_JSON" ] && break
    sleep 0.5
done

if [ -z "$MONITORS_JSON" ] || ! command -v jq &>/dev/null; then
    exec waybar
fi

# Strip // line comments (waybar uses JSONC) before parsing with jq
BASE=$(sed 's|^\s*//.*||' "$TEMPLATE" | jq '.[0] | del(.output)')

if [ -z "$BASE" ]; then
    exec waybar
fi

MON_ARRAY=$(echo "$MONITORS_JSON" | jq '[.[].name]')

jq -n \
    --argjson base "$BASE" \
    --argjson monitors "$MON_ARRAY" \
    '[$monitors[] | . as $m | $base + {"output": $m}]' > "$RUNTIME"

exec waybar -c "$RUNTIME"
