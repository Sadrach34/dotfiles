#!/bin/bash
# /* ---- WallpaperApply.sh ---- */
# Llamado desde el QS WallpaperPicker para aplicar fondos.
# Recibe: $1 = tipo ("video" | "image")  $2 = ruta completa al archivo

TYPE="$1"
FILE="$2"
WALLPAPER_CURRENT="$HOME/.config/hypr/wallpaper_effects/.wallpaper_current"
STARTUP="$HOME/.config/hypr/UserConfigs/Startup_Apps.conf"

FPS=60
TTYPE="any"
DURATION=2
BEZIER=".43,1.19,1,.4"
SWWW_PARAMS="--transition-fps $FPS --transition-type $TTYPE --transition-duration $DURATION --transition-bezier $BEZIER"
WALL_CMD=""
WALL_DAEMON_CMD=""
WALL_DAEMON_FORMAT=""

detect_wall_backend() {
  if command -v swww >/dev/null 2>&1 && command -v swww-daemon >/dev/null 2>&1; then
    WALL_CMD="swww"
    WALL_DAEMON_CMD="swww-daemon"
    WALL_DAEMON_FORMAT="xrgb"
    return 0
  fi

  if command -v awww >/dev/null 2>&1 && command -v awww-daemon >/dev/null 2>&1; then
    WALL_CMD="awww"
    WALL_DAEMON_CMD="awww-daemon"
    WALL_DAEMON_FORMAT="argb"
    return 0
  fi

  return 1
}

ensure_state_dirs() {
  mkdir -p "$HOME/.config/hypr/wallpaper_effects" "$HOME/.config/rofi"
}

set_startup_mode_video() {
  [[ -f "$STARTUP" ]] || return 0

  sed -Ei 's|^([[:space:]]*)exec-once[[:space:]]*=[[:space:]]*swww-daemon[[:space:]]+--format[[:space:]]+xrgb[[:space:]]*$|#\0|' "$STARTUP" 2>/dev/null
  sed -Ei 's|^[[:space:]]*#[[:space:]]*(exec-once[[:space:]]*=[[:space:]]*mpvpaper.*)$|\1|' "$STARTUP" 2>/dev/null

  ESCAPED_FILE="${FILE/#$HOME/\$HOME}"
  ESCAPED_FILE="$ESCAPED_FILE" perl -i -pe 'BEGIN{$f=$ENV{"ESCAPED_FILE"}} s/^\$livewallpaper=.*/\$livewallpaper="$f"/' "$STARTUP" 2>/dev/null
}

set_startup_mode_image() {
  [[ -f "$STARTUP" ]] || return 0

  sed -Ei 's|^[[:space:]]*#[[:space:]]*(exec-once[[:space:]]*=[[:space:]]*swww-daemon[[:space:]]+--format[[:space:]]+xrgb[[:space:]]*)$|\1|' "$STARTUP" 2>/dev/null
  sed -Ei 's|^([[:space:]]*)exec-once[[:space:]]*=[[:space:]]*mpvpaper.*$|#\0|' "$STARTUP" 2>/dev/null
}

kill_for_video() {
  if [[ -z "$WALL_CMD" ]]; then
    detect_wall_backend || true
  fi
  [[ -n "$WALL_CMD" ]] && "$WALL_CMD" kill 2>/dev/null
  pkill mpvpaper 2>/dev/null
  pkill swaybg 2>/dev/null
  pkill hyprpaper 2>/dev/null
}

kill_for_image() {
  pkill mpvpaper 2>/dev/null
  pkill swaybg 2>/dev/null
  pkill hyprpaper 2>/dev/null
}

if [[ "$TYPE" == "video" ]]; then
  ensure_state_dirs
  kill_for_video
  mpvpaper '*' -o "--load-scripts=no --no-audio --loop --panscan=1.0" "$FILE" >/dev/null 2>&1 &
  ln -sf "$FILE" "$WALLPAPER_CURRENT" 2>/dev/null
  set_startup_mode_video
else
  ensure_state_dirs
  if ! detect_wall_backend; then
    echo "ERROR: no se encontro backend de wallpaper para imagenes (swww/awww)" >&2
    exit 1
  fi
  kill_for_image
  if ! pgrep -x "$WALL_DAEMON_CMD" >/dev/null; then
    "$WALL_DAEMON_CMD" --format "$WALL_DAEMON_FORMAT" >/dev/null 2>&1 &
  fi

  for _ in {1..20}; do
    if "$WALL_CMD" query >/dev/null 2>&1; then
      break
    fi
    sleep 0.2
  done

  if ! "$WALL_CMD" query >/dev/null 2>&1; then
    echo "ERROR: no responde $WALL_DAEMON_CMD" >&2
    exit 1
  fi

  if ! "$WALL_CMD" img "$FILE" $SWWW_PARAMS >/dev/null 2>&1; then
    echo "ERROR: fallo al aplicar imagen: $FILE" >&2
    exit 1
  fi

  ln -sf "$FILE" "$WALLPAPER_CURRENT" 2>/dev/null
  ln -sf "$FILE" "$HOME/.config/rofi/.current_wallpaper" 2>/dev/null
  set_startup_mode_image
fi

# Reiniciar temporizador de auto-cambio de wallpaper (si está corriendo)
AUTO_PIDFILE="/tmp/wallpaper_auto_change_mixed.pid"
if [[ -f "$AUTO_PIDFILE" ]]; then
  AUTO_PID=$(cat "$AUTO_PIDFILE")
  if kill -0 "$AUTO_PID" 2>/dev/null; then
    kill -USR2 "$AUTO_PID" 2>/dev/null
  fi
fi
