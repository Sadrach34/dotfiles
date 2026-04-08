#!/usr/bin/env bash
set -euo pipefail

WALL_DIR="$HOME/Pictures/wallpapers"
CURRENT_LINK="$HOME/.config/hypr/wallpaper_effects/.wallpaper_current"
APPLY_SCRIPT="$HOME/.config/hypr/UserScripts/WallpaperApply.sh"
SKWD_STATE_FILE="$HOME/.cache/skwd-wall/last-wallpaper.json"
CACHE_DIR="$HOME/.cache/hypr/wallpaper-index"
CACHE_FILE="$CACHE_DIR/next-list.bin"
CACHE_TTL=20
SKWD_CONFIG_FILE="$HOME/.config/skwd-wall/config.json"
DEFAULT_WE_DIR="$HOME/.local/share/Steam/steamapps/workshop/content/431960"
WE_DIR="$DEFAULT_WE_DIR"

if [[ ! -d "$WALL_DIR" ]]; then
  echo "ERROR: wallpaper dir not found: $WALL_DIR" >&2
  exit 1
fi

if [[ ! -x "$APPLY_SCRIPT" ]]; then
  echo "ERROR: apply script missing or not executable: $APPLY_SCRIPT" >&2
  exit 1
fi

mkdir -p "$CACHE_DIR"

resolve_we_dir() {
  if [[ -f "$SKWD_CONFIG_FILE" ]] && command -v jq >/dev/null 2>&1; then
    local cfg_we_dir
    cfg_we_dir="$(jq -r '.paths.steamWorkshop // empty' "$SKWD_CONFIG_FILE" 2>/dev/null || true)"
    [[ -n "$cfg_we_dir" ]] && WE_DIR="$cfg_we_dir"
  fi
}

resolve_current_key() {
  local state_type state_we state_path current current_base

  if [[ -f "$SKWD_STATE_FILE" ]] && command -v jq >/dev/null 2>&1; then
    state_type="$(jq -r '.type // empty' "$SKWD_STATE_FILE" 2>/dev/null || true)"
    if [[ "$state_type" == "we" ]]; then
      state_we="$(jq -r '.we_id // empty' "$SKWD_STATE_FILE" 2>/dev/null || true)"
      if [[ -n "$state_we" ]]; then
        printf 'we:%s' "$state_we"
        return 0
      fi
    fi
    if [[ "$state_type" == "static" || "$state_type" == "video" ]]; then
      state_path="$(jq -r '.path // empty' "$SKWD_STATE_FILE" 2>/dev/null || true)"
      if [[ -n "$state_path" ]]; then
        state_path="$(readlink -f "$state_path" 2>/dev/null || printf '%s' "$state_path")"
        printf '%s' "$state_path"
        return 0
      fi
    fi
  fi

  current=""
  if [[ -e "$CURRENT_LINK" ]]; then
    current="$(readlink -f "$CURRENT_LINK" 2>/dev/null || true)"
  fi

  current_base="${current##*/}"
  if [[ -n "$current" && "$current_base" != "wallpaper.jpg" && "$current_base" != "lockscreen-video.mp4" ]]; then
    printf '%s' "$current"
  fi
}

run_apply() {
  local mode="$1"
  local target="$2"
  local attempts=20
  local errf
  errf="$(mktemp)"
  for _ in $(seq 1 "$attempts"); do
    if "$APPLY_SCRIPT" "$mode" "$target" 2>"$errf"; then
      rm -f "$errf"
      exit 0
    fi
    rc=$?
    if grep -q "wallpaper apply ocupado" "$errf" 2>/dev/null; then
      sleep 0.4
      continue
    fi
    cat "$errf" >&2
    rm -f "$errf"
    exit "$rc"
  done
  cat "$errf" >&2
  rm -f "$errf"
  exit 1
}

rebuild_cache() {
  local tmp
  tmp="${CACHE_FILE}.tmp"
  {
    find "$WALL_DIR" -maxdepth 1 -type f \( \
      -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o \
      -iname '*.gif' -o -iname '*.mp4' -o -iname '*.mkv' -o -iname '*.mov' -o -iname '*.webm' \
    \) \
    ! -iname 'wallpaper.jpg' \
    ! -iname 'lockscreen-video.mp4' \
    -print0 | sort -z

    if [[ -d "$WE_DIR" ]]; then
      find "$WE_DIR" -mindepth 1 -maxdepth 1 -type d -printf 'we:%f\0' | sort -z
    fi
  } > "$tmp"
  mv -f "$tmp" "$CACHE_FILE"
}

cache_stale=1
if [[ -f "$CACHE_FILE" ]]; then
  now_ts="$(date +%s)"
  cache_ts="$(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)"
  if (( now_ts - cache_ts <= CACHE_TTL )) && [[ "$WALL_DIR" -ot "$CACHE_FILE" ]]; then
    cache_stale=0
  fi
fi

if (( cache_stale )); then
  resolve_we_dir
  rebuild_cache
fi

mapfile -d '' FILES < "$CACHE_FILE"

if (( ${#FILES[@]} == 0 )); then
  echo "ERROR: no wallpapers found in $WALL_DIR" >&2
  exit 1
fi

CURRENT_KEY="$(resolve_current_key || true)"

NEXT_INDEX=0
if [[ -n "$CURRENT_KEY" ]]; then
  for i in "${!FILES[@]}"; do
    CANDIDATE="${FILES[$i]%$'\0'}"
    if [[ "$CANDIDATE" == "$CURRENT_KEY" ]]; then
      NEXT_INDEX=$(( (i + 1) % ${#FILES[@]} ))
      break
    fi
  done
fi

NEXT_ITEM="${FILES[$NEXT_INDEX]%$'\0'}"

if [[ "$NEXT_ITEM" == we:* ]]; then
  WE_ID="${NEXT_ITEM#we:}"
  run_apply "we" "$WE_ID"
fi

LOWER="${NEXT_ITEM,,}"
TYPE="image"
if [[ "$LOWER" == *.mp4 || "$LOWER" == *.mkv || "$LOWER" == *.mov || "$LOWER" == *.webm ]]; then
  TYPE="video"
fi

run_apply "$TYPE" "$NEXT_ITEM"
