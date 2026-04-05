#!/usr/bin/env bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */
# Contributor: sadrach34 (mods and maintenance)
# Script for Random Wallpaper (CTRL ALT W / SUPER ALT W)

set -euo pipefail

WALL_DIR="$HOME/Pictures/wallpapers"
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
	find -L "$WALL_DIR" -type f \( \
		-iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o \
		-iname '*.bmp' -o -iname '*.gif' -o -iname '*.tga' -o -iname '*.tiff' -o \
		-iname '*.pnm' -o -iname '*.farbfeld' -o \
		-iname '*.mp4' -o -iname '*.mkv' -o -iname '*.mov' -o -iname '*.webm' -o -iname '*.avi' \
	\) -print0
)

if (( ${#FILES[@]} == 0 )); then
	echo "ERROR: no wallpapers found in $WALL_DIR" >&2
	exit 1
fi

idx=$(( RANDOM % ${#FILES[@]} ))
RANDOM_FILE="${FILES[$idx]%$'\0'}"
LOWER="${RANDOM_FILE,,}"

TYPE="image"
if [[ "$LOWER" == *.mp4 || "$LOWER" == *.mkv || "$LOWER" == *.mov || "$LOWER" == *.webm || "$LOWER" == *.avi ]]; then
	TYPE="video"
fi

exec "$APPLY_SCRIPT" "$TYPE" "$RANDOM_FILE"

