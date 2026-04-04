#!/usr/bin/env bash
set -euo pipefail

WALL_DIR="$HOME/Pictures/wallpapers"
CURRENT_LINK="$HOME/.config/hypr/wallpaper_effects/.wallpaper_current"
APPLY_SCRIPT="$HOME/.config/hypr/UserScripts/WallpaperApply.sh"

if [[ ! -d "$WALL_DIR" ]]; then
  echo "ERROR: wallpaper dir not found: $WALL_DIR" >&2
  exit 1
fi

if [[ ! -x "$APPLY_SCRIPT" ]]; then
  echo "ERROR: apply script missing or not executable: $APPLY_SCRIPT" >&2
  exit 1
fi

mapfile -d '' FILES < <(
  find "$WALL_DIR" -maxdepth 1 -type f \( \
    -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o \
    -iname '*.gif' -o -iname '*.mp4' -o -iname '*.mkv' -o -iname '*.mov' -o -iname '*.webm' \
  \) -print0 | sort -z
)

if (( ${#FILES[@]} == 0 )); then
  echo "ERROR: no wallpapers found in $WALL_DIR" >&2
  exit 1
fi

CURRENT=""
if [[ -e "$CURRENT_LINK" ]]; then
  CURRENT="$(readlink -f "$CURRENT_LINK" 2>/dev/null || true)"
fi

NEXT_INDEX=0
if [[ -n "$CURRENT" ]]; then
  for i in "${!FILES[@]}"; do
    CANDIDATE="${FILES[$i]%$'\0'}"
    if [[ "$CANDIDATE" == "$CURRENT" ]]; then
      NEXT_INDEX=$(( (i + 1) % ${#FILES[@]} ))
      break
    fi
  done
fi

NEXT_FILE="${FILES[$NEXT_INDEX]%$'\0'}"
LOWER="${NEXT_FILE,,}"
TYPE="image"
if [[ "$LOWER" == *.mp4 || "$LOWER" == *.mkv || "$LOWER" == *.mov || "$LOWER" == *.webm || "$LOWER" == *.gif ]]; then
  TYPE="video"
fi

exec "$APPLY_SCRIPT" "$TYPE" "$NEXT_FILE"
