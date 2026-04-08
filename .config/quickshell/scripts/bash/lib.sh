#!/bin/bash
# Shared library: environment variables, config helpers, command checks, compositor detection

# Standard paths (XDG-aware)
export SKWD_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"
export SKWD_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell"
export SKWD_RUNTIME="${XDG_RUNTIME_DIR:-/tmp}/skwd"
export SKWD_INSTALL="${SKWD_INSTALL:-$SKWD_CONFIG}"
export SKWD_CFG="$SKWD_CONFIG/data/config.json"
export SKWD_MATUGEN_CONFIG="$SKWD_CACHE/matugen-config.toml"

# Ensure runtime and cache directories exist
mkdir -p "$SKWD_RUNTIME" 2>/dev/null
mkdir -p "$SKWD_CACHE" 2>/dev/null
mkdir -p "$SKWD_CACHE/wallpaper" 2>/dev/null
mkdir -p "$SKWD_CACHE/app-launcher" 2>/dev/null

# Seed cache files that QML components expect
[ -f "$SKWD_CACHE/bar-state" ] || echo "true" > "$SKWD_CACHE/bar-state" 2>/dev/null
[ -f "$SKWD_CACHE/colors.json" ] || echo '{}' > "$SKWD_CACHE/colors.json" 2>/dev/null
[ -f "$SKWD_CACHE/wallpaper/tags.json" ] || echo '{}' > "$SKWD_CACHE/wallpaper/tags.json" 2>/dev/null
[ -f "$SKWD_CACHE/wallpaper/colors.json" ] || echo '{}' > "$SKWD_CACHE/wallpaper/colors.json" 2>/dev/null
[ -f "$SKWD_CACHE/wallpaper/matugen-colors.json" ] || echo '{}' > "$SKWD_CACHE/wallpaper/matugen-colors.json" 2>/dev/null
[ -f "$SKWD_CACHE/app-launcher/freq.json" ] || echo '{}' > "$SKWD_CACHE/app-launcher/freq.json" 2>/dev/null

# Read a jq path from config.json, expand ~ to $HOME
cfg_get() {
  local val
  val=$(jq -r "$1" "$SKWD_CFG" 2>/dev/null)
  [ "$val" = "null" ] && val=""
  echo "${val/#\~/$HOME}"
}

# Abort if any listed commands are missing
require_cmd() {
  local missing=()
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
  done
  if [ ${#missing[@]} -gt 0 ]; then
    echo "skwd: missing required commands: ${missing[*]}" >&2
    echo "  Install them and try again." >&2
    exit 1
  fi
}

# Silent command existence check
has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

apply_kde_colors() {
  local scheme_name="${1:-SkwdMatugen}"
  local scheme_file="$HOME/.local/share/color-schemes/${scheme_name}.colors"
  local kdeglobals="$HOME/.config/kdeglobals"

  [ -f "$scheme_file" ] || return 0

  has_cmd kwriteconfig6 && kwriteconfig6 --file kdeglobals --group General --key ColorScheme "$scheme_name"

  python3 -c "
import configparser, sys, os

scheme = configparser.ConfigParser(interpolation=None)
scheme.optionxform = str  # preserve case
scheme.read(sys.argv[1])

target = configparser.ConfigParser(interpolation=None)
target.optionxform = str
target.read(sys.argv[2])

for section in scheme.sections():
    if not target.has_section(section):
        target.add_section(section)
    for key, val in scheme.items(section):
        target.set(section, key, val)

with open(sys.argv[2], 'w') as f:
    target.write(f, space_around_delimiters=False)
" "$scheme_file" "$kdeglobals"

  has_cmd gdbus && gdbus emit --session --object-path /kdeglobals --signal org.kde.kconfig.notify.ConfigChanged \
    "{'General': [[byte 0x43, 0x6f, 0x6c, 0x6f, 0x72, 0x53, 0x63, 0x68, 0x65, 0x6d, 0x65]]}"
}

# Auto-detect compositor from config or running process
detect_compositor() {
  local configured
  configured=$(jq -r '.compositor // ""' "$SKWD_CFG" 2>/dev/null)
  if [ -n "$configured" ] && [ "$configured" != "null" ]; then
    echo "$configured"
    return
  fi
  if has_cmd niri && pgrep -x niri >/dev/null 2>&1; then
    echo "niri"
  elif [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
    echo "hyprland"
  elif [ -n "$SWAYSOCK" ]; then
    echo "sway"
  elif pgrep -x kwin_wayland >/dev/null 2>&1 || pgrep -x kwin_x11 >/dev/null 2>&1; then
    echo "kwin"
  else
    echo "unknown"
  fi
}

export SKWD_COMPOSITOR="${SKWD_COMPOSITOR:-$(detect_compositor)}"

# GPU vendor detection (nvidia/amd/intel)
detect_gpu() {
  if has_cmd nvidia-smi; then
    echo "nvidia"
  elif [ -d /sys/class/drm/card0/device ] && grep -qi amd /sys/class/drm/card0/device/vendor 2>/dev/null; then
    echo "amd"
  elif [ -d /sys/class/drm/card0/device ] && grep -qi intel /sys/class/drm/card0/device/vendor 2>/dev/null; then
    echo "intel"
  else
    echo "unknown"
  fi
}
