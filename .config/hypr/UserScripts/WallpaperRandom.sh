#!/usr/bin/env bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */
# Contributor: sadrach34 (mods and maintenance)
# Script for Random Wallpaper (CTRL ALT W / SUPER ALT W)

set -euo pipefail

APPLY_SCRIPT="$HOME/.config/hypr/UserScripts/WallpaperApply.sh"
CACHE_DIR="$HOME/.cache/hypr/wallpaper-index"
CACHE_TTL=20
SKWD_CONFIG_FILE="$HOME/.config/skwd-wall/config.json"
DEFAULT_WE_DIR="$HOME/.local/share/Steam/steamapps/workshop/content/431960"
WE_DIR="$DEFAULT_WE_DIR"
MONITORS_CONF="$HOME/.config/hypr/monitors.conf"

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

get_wall_dir_for_monitor() {
	local mon="$1"
	local transform
	transform=$(grep -oP "monitor=${mon},transform,\K[0-9]+" "$MONITORS_CONF" 2>/dev/null || echo "0")
	if [[ "$transform" == "1" ]]; then
		echo "$HOME/Pictures/wallpaperVertical"
	else
		echo "$HOME/Pictures/wallpapers"
	fi
}

resolve_current_key_for_monitor() {
	local mon="$1"
	local state_file="$HOME/.cache/skwd-wall/last-wallpaper-${mon}.json"
	local state_type state_path
	if [[ -f "$state_file" ]] && command -v jq >/dev/null 2>&1; then
		state_type="$(jq -r '.type // empty' "$state_file" 2>/dev/null || true)"
		if [[ "$state_type" == "we" ]]; then
			local state_we
			state_we="$(jq -r '.we_id // empty' "$state_file" 2>/dev/null || true)"
			[[ -n "$state_we" ]] && printf 'we:%s' "$state_we"
			return 0
		fi
		if [[ "$state_type" == "static" || "$state_type" == "video" ]]; then
			state_path="$(jq -r '.path // empty' "$state_file" 2>/dev/null || true)"
			if [[ -n "$state_path" ]]; then
				readlink -f "$state_path" 2>/dev/null || printf '%s' "$state_path"
				return 0
			fi
		fi
	fi
}

rebuild_cache_for_dir() {
	local wall_dir="$1"
	local cache_file="$2"
	local include_we="$3"
	local tmp="${cache_file}.tmp"
	{
		find "$wall_dir" -maxdepth 1 -type f \( \
			-iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o \
			-iname '*.bmp' -o -iname '*.gif' -o -iname '*.tga' -o -iname '*.tiff' -o \
			-iname '*.pnm' -o -iname '*.farbfeld' -o \
			-iname '*.mp4' -o -iname '*.mkv' -o -iname '*.mov' -o -iname '*.webm' -o -iname '*.avi' \
		\) \
		! -iname 'wallpaper.jpg' \
		! -iname 'lockscreen-video.mp4' \
		-print0

		if [[ "$include_we" == "1" && -d "$WE_DIR" ]]; then
			find "$WE_DIR" -mindepth 1 -maxdepth 1 -type d -printf 'we:%f\0'
		fi
	} > "$tmp"
	mv -f "$tmp" "$cache_file"
}

run_apply_for_monitor() {
	local mon="$1"
	local mode="$2"
	local target="$3"
	local attempts=20
	local errf rc
	errf="$(mktemp)"
	for _ in $(seq 1 "$attempts"); do
		if WALL_OUTPUT="$mon" "$APPLY_SCRIPT" "$mode" "$target" 2>"$errf"; then
			rm -f "$errf"
			return 0
		fi
		rc=$?
		if grep -q "wallpaper apply ocupado" "$errf" 2>/dev/null; then
			sleep 0.4
			continue
		fi
		cat "$errf" >&2
		rm -f "$errf"
		return "$rc"
	done
	cat "$errf" >&2
	rm -f "$errf"
	return 1
}

resolve_we_dir

mapfile -t MONITORS < <(hyprctl monitors -j 2>/dev/null | jq -r '.[].name' 2>/dev/null || true)

if (( ${#MONITORS[@]} == 0 )); then
	echo "ERROR: no monitors detected" >&2
	exit 1
fi

for mon in "${MONITORS[@]}"; do
	[[ -z "$mon" ]] && continue

	WALL_DIR="$(get_wall_dir_for_monitor "$mon")"
	WALL_DIRNAME="$(basename "$WALL_DIR")"
	INCLUDE_WE=0
	[[ "$WALL_DIRNAME" == "wallpapers" ]] && INCLUDE_WE=1

	if [[ ! -d "$WALL_DIR" ]]; then
		echo "ERROR: wallpaper dir not found for $mon: $WALL_DIR" >&2
		continue
	fi

	CACHE_FILE="$CACHE_DIR/random-${WALL_DIRNAME}.bin"

	cache_stale=1
	if [[ -f "$CACHE_FILE" ]]; then
		now_ts="$(date +%s)"
		cache_ts="$(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)"
		if (( now_ts - cache_ts <= CACHE_TTL )) && [[ "$WALL_DIR" -ot "$CACHE_FILE" ]]; then
			cache_stale=0
		fi
	fi

	if (( cache_stale )); then
		rebuild_cache_for_dir "$WALL_DIR" "$CACHE_FILE" "$INCLUDE_WE"
	fi

	mapfile -d '' FILES < "$CACHE_FILE"

	if (( ${#FILES[@]} == 0 )); then
		echo "ERROR: no wallpapers found in $WALL_DIR" >&2
		continue
	fi

	CURRENT_KEY="$(resolve_current_key_for_monitor "$mon" || true)"

	idx=$(( RANDOM % ${#FILES[@]} ))
	RANDOM_ITEM="${FILES[$idx]%$'\0'}"
	if (( ${#FILES[@]} > 1 )) && [[ -n "$CURRENT_KEY" ]]; then
		for _ in {1..8}; do
			[[ "$RANDOM_ITEM" != "$CURRENT_KEY" ]] && break
			idx=$(( RANDOM % ${#FILES[@]} ))
			RANDOM_ITEM="${FILES[$idx]%$'\0'}"
		done
	fi

	TYPE="image"
	if [[ "$RANDOM_ITEM" == we:* ]]; then
		WE_ID="${RANDOM_ITEM#we:}"
		run_apply_for_monitor "$mon" "we" "$WE_ID"
		continue
	fi

	LOWER="${RANDOM_ITEM,,}"
	if [[ "$LOWER" == *.mp4 || "$LOWER" == *.mkv || "$LOWER" == *.mov || "$LOWER" == *.webm || "$LOWER" == *.avi ]]; then
		TYPE="video"
	fi

	run_apply_for_monitor "$mon" "$TYPE" "$RANDOM_ITEM"
done
