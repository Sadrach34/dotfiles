#!/bin/bash
# /* ---- WallpaperApply.sh ---- */
# Llamado desde el QS WallpaperPicker para aplicar fondos.
# Recibe: $1 = tipo ("video" | "image")  $2 = ruta completa al archivo

if [[ $# -lt 2 ]]; then
  echo "USO: $0 <video|image|we> <ruta-archivo|we_id>" >&2
  exit 1
fi

TYPE="$1"
FILE="$2"
WALL_OUTPUT="${WALL_OUTPUT:-}"
WALLPAPER_CURRENT="$HOME/.config/hypr/wallpaper_effects/.wallpaper_current"
STARTUP="$HOME/.config/hypr/UserConfigs/Startup_Apps.conf"
SKWD_STATE_FILE="$HOME/.cache/skwd-wall/last-wallpaper${WALL_OUTPUT:+-$WALL_OUTPUT}.json"
LOCK_DIR="$HOME/.cache/hypr/wallpaper-apply.lock.d"
SKWD_CONFIG_FILE="$HOME/.config/skwd-wall/config.json"
DEFAULT_WE_DIR="$HOME/.local/share/Steam/steamapps/workshop/content/431960"
DEFAULT_WE_ASSETS="$HOME/.local/share/Steam/steamapps/common/wallpaper_engine/assets"
WE_DIR=""
WE_ASSETS_DIR=""
WE_BIN="/usr/bin/linux-wallpaperengine"
PREV_TYPE=""

if [[ -f "$SKWD_STATE_FILE" ]] && command -v jq >/dev/null 2>&1; then
  PREV_TYPE="$(jq -r '.type // empty' "$SKWD_STATE_FILE" 2>/dev/null || true)"
fi

mkdir -p "$(dirname "$LOCK_DIR")"
acquire_lock() {
  if mkdir "$LOCK_DIR" 2>/dev/null; then
    printf '%s\n' "$$" > "$LOCK_DIR/pid"
    return 0
  fi

  if [[ -f "$LOCK_DIR/pid" ]]; then
    local lock_pid
    lock_pid="$(cat "$LOCK_DIR/pid" 2>/dev/null || true)"
    if [[ -n "$lock_pid" ]] && ! kill -0 "$lock_pid" 2>/dev/null; then
      rm -rf "$LOCK_DIR" 2>/dev/null || true
      if mkdir "$LOCK_DIR" 2>/dev/null; then
        printf '%s\n' "$$" > "$LOCK_DIR/pid"
        return 0
      fi
    fi
  fi

  return 1
}

if ! acquire_lock; then
  echo "ERROR: wallpaper apply ocupado, intenta de nuevo" >&2
  exit 1
fi

cleanup_lock() {
  rm -rf "$LOCK_DIR" 2>/dev/null || true
}
trap cleanup_lock EXIT INT TERM

if [[ "$TYPE" != "we" ]]; then
  FILE="$(readlink -f "$FILE" 2>/dev/null || printf '%s' "$FILE")"
  BASE_FILE="${FILE##*/}"
  if [[ "$BASE_FILE" == "wallpaper.jpg" || "$BASE_FILE" == "lockscreen-video.mp4" ]]; then
    echo "ERROR: archivo auxiliar no permitido como wallpaper: $FILE" >&2
    exit 1
  fi

  if [[ ! -f "$FILE" ]]; then
    echo "ERROR: archivo no encontrado: $FILE" >&2
    exit 1
  fi
fi

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
  mkdir -p "$(dirname "$SKWD_STATE_FILE")"
}

write_skwd_state() {
  local state_type="$1"
  if command -v jq >/dev/null 2>&1; then
    jq -n --arg type "$state_type" --arg path "$FILE" '{type:$type,path:$path}' > "$SKWD_STATE_FILE"
  else
    printf '{"type":"%s","path":"%s"}\n' "$state_type" "$FILE" > "$SKWD_STATE_FILE"
  fi
}

write_skwd_state_we() {
  local we_id="$1"
  if command -v jq >/dev/null 2>&1; then
    jq -n --arg type "we" --arg we_id "$we_id" '{type:$type,we_id:$we_id}' > "$SKWD_STATE_FILE"
  else
    printf '{"type":"we","we_id":"%s"}\n' "$we_id" > "$SKWD_STATE_FILE"
  fi
}

resolve_we_paths() {
  WE_DIR="$DEFAULT_WE_DIR"
  WE_ASSETS_DIR="$DEFAULT_WE_ASSETS"
  if [[ -f "$SKWD_CONFIG_FILE" ]] && command -v jq >/dev/null 2>&1; then
    local cfg_we_dir cfg_assets
    cfg_we_dir="$(jq -r '.paths.steamWorkshop // empty' "$SKWD_CONFIG_FILE" 2>/dev/null || true)"
    cfg_assets="$(jq -r '.paths.steamWeAssets // empty' "$SKWD_CONFIG_FILE" 2>/dev/null || true)"
    [[ -n "$cfg_we_dir" ]] && WE_DIR="$cfg_we_dir"
    [[ -n "$cfg_assets" ]] && WE_ASSETS_DIR="$cfg_assets"
  fi
}

build_we_screen_args() {
  if ! command -v hyprctl >/dev/null 2>&1; then
    return 0
  fi
  if ! command -v jq >/dev/null 2>&1; then
    return 0
  fi
  hyprctl -j monitors 2>/dev/null | jq -r '.[].name // empty' 2>/dev/null | while IFS= read -r mon; do
    [[ -n "$mon" ]] && printf -- ' --screen-root %q --scaling fill --clamp border' "$mon"
  done
}

stop_we_engine() {
  local pids pid

  pids="$(pgrep -f '(^|/)linux-wallpaperengine([[:space:]]|$)' 2>/dev/null || true)"
  if [[ -n "$pids" ]]; then
    for pid in $pids; do
      kill -TERM "$pid" 2>/dev/null || true
    done
  fi

  for _ in {1..40}; do
    pgrep -f '(^|/)linux-wallpaperengine([[:space:]]|$)' >/dev/null 2>&1 || break
    sleep 0.05
  done

  pids="$(pgrep -f '(^|/)linux-wallpaperengine([[:space:]]|$)' 2>/dev/null || true)"
  if [[ -n "$pids" ]]; then
    for pid in $pids; do
      kill -KILL "$pid" 2>/dev/null || true
    done
  fi

  for _ in {1..20}; do
    pgrep -f '(^|/)linux-wallpaperengine([[:space:]]|$)' >/dev/null 2>&1 || break
    sleep 0.05
  done
}

apply_we() {
  local we_id="$1"
  local we_item_dir preview
  resolve_we_paths
  we_item_dir="$WE_DIR/$we_id"
  if [[ ! -d "$we_item_dir" ]]; then
    echo "ERROR: WE id no encontrado en workshop local: $we_id" >&2
    exit 1
  fi

  ensure_state_dirs
  stop_we_engine
  pkill mpvpaper 2>/dev/null
  pkill awww 2>/dev/null
  pkill awww-daemon 2>/dev/null
  pkill hyprpaper 2>/dev/null

  local screen_args assets_args
  screen_args="$(build_we_screen_args)"
  assets_args=""
  [[ -d "$WE_ASSETS_DIR" ]] && assets_args=" --assets-dir $(printf %q "$WE_ASSETS_DIR")"

  if ! command -v "$WE_BIN" >/dev/null 2>&1; then
    echo "ERROR: no se encontro linux-wallpaperengine en $WE_BIN" >&2
    exit 1
  fi

  # shellcheck disable=SC2086
  nohup setsid "$WE_BIN" --silent --no-fullscreen-pause --noautomute --set-property bmomode=0 $screen_args $assets_args "$we_id" </dev/null >/dev/null 2>&1 &

  preview="$(find "$we_item_dir" -maxdepth 1 -type f \( -iname 'preview.jpg' -o -iname 'preview.png' -o -iname 'preview.gif' \) -print -quit 2>/dev/null || true)"
  if [[ -n "$preview" ]]; then
    ln -sf "$preview" "$WALLPAPER_CURRENT" 2>/dev/null
    ln -sf "$preview" "$HOME/.config/rofi/.current_wallpaper" 2>/dev/null
  fi

  write_skwd_state_we "$we_id"
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

current_static_path() {
  local line
  if [[ -n "$WALL_OUTPUT" ]]; then
    line="$($WALL_CMD query 2>/dev/null | grep "^${WALL_OUTPUT}:" | head -n 1 || true)"
  else
    line="$($WALL_CMD query 2>/dev/null | head -n 1 || true)"
  fi
  printf '%s' "$line" | sed -n 's/.*currently displaying: image: \([^,]*\).*/\1/p'
}

apply_static_once() {
  local target="$1"
  local params="$2"
  # shellcheck disable=SC2086
  if [[ -n "$WALL_OUTPUT" ]]; then
    "$WALL_CMD" img -o "$WALL_OUTPUT" "$target" $params >/dev/null 2>&1
  else
    "$WALL_CMD" img "$target" $params >/dev/null 2>&1
  fi
}

ensure_static_applied() {
  local target="$1"
  local force_settle="$2"
  if [[ "$WALL_CMD" == "awww" ]]; then
    if [[ "$force_settle" == "1" ]]; then
      apply_static_once "$target" "--transition-type none --transition-duration 0"
    fi
    return 0
  fi

  local target_abs shown
  target_abs="$(readlink -f "$target" 2>/dev/null || printf '%s' "$target")"

  shown="$(current_static_path)"
  shown="$(readlink -f "$shown" 2>/dev/null || printf '%s' "$shown")"
  if [[ -n "$shown" && "$shown" == "$target_abs" ]]; then
    return 0
  fi

  if [[ -n "$WALL_OUTPUT" ]]; then
    apply_static_once "$target" "--transition-type none --transition-duration 0"
    return 0
  fi

  pkill -TERM -x "$WALL_DAEMON_CMD" 2>/dev/null || true
  "$WALL_DAEMON_CMD" --format "$WALL_DAEMON_FORMAT" >/dev/null 2>&1 &

  for _ in {1..20}; do
    "$WALL_CMD" query >/dev/null 2>&1 && break
    sleep 0.1
  done

  apply_static_once "$target" "--transition-type none --transition-duration 0"
}

restart_wall_backend() {
  [[ -z "$WALL_DAEMON_CMD" ]] && return 0
  [[ -n "$WALL_OUTPUT" ]] && return 0
  pkill -TERM -x "$WALL_DAEMON_CMD" 2>/dev/null || true
  sleep 0.12
  "$WALL_DAEMON_CMD" --format "$WALL_DAEMON_FORMAT" >/dev/null 2>&1 &
}

kill_for_video() {
  if [[ -z "$WALL_CMD" ]]; then
    detect_wall_backend || true
  fi
  if [[ -n "$WALL_OUTPUT" ]]; then
    pkill -f "mpvpaper[[:space:]]+${WALL_OUTPUT}([[:space:]]|$)" 2>/dev/null || true
  else
    [[ -n "$WALL_CMD" ]] && "$WALL_CMD" kill 2>/dev/null
    stop_we_engine
    stop_video_wallpaper
  fi
  pkill swaybg 2>/dev/null
  pkill hyprpaper 2>/dev/null
}

kill_for_image() {
  stop_we_engine
  if [[ -n "$WALL_OUTPUT" ]]; then
    pkill -f "mpvpaper[[:space:]]+${WALL_OUTPUT}([[:space:]]|$)" 2>/dev/null || true
  else
    stop_video_wallpaper
  fi
  pkill swaybg 2>/dev/null
  pkill hyprpaper 2>/dev/null
}

stop_video_wallpaper() {
  local pids pid
  pids="$(pgrep -x mpvpaper 2>/dev/null || true)"

  if [[ -n "$pids" ]]; then
    for pid in $pids; do
      pkill -TERM -P "$pid" 2>/dev/null || true
    done
  fi

  pkill -TERM -x mpvpaper 2>/dev/null || true
  pkill -TERM -f 'mpv.*--no-audio --loop --panscan=1.0' 2>/dev/null || true

  for _ in {1..20}; do
    pgrep -x mpvpaper >/dev/null 2>&1 || break
    sleep 0.05
  done

  pids="$(pgrep -x mpvpaper 2>/dev/null || true)"
  if [[ -n "$pids" ]]; then
    for pid in $pids; do
      pkill -KILL -P "$pid" 2>/dev/null || true
      kill -9 "$pid" 2>/dev/null || true
    done
  fi

  pkill -KILL -f 'mpv.*--no-audio --loop --panscan=1.0' 2>/dev/null || true
}

if [[ "$TYPE" == "we" ]]; then
  apply_we "$FILE"
elif [[ "$TYPE" == "video" ]]; then
  ensure_state_dirs
  kill_for_video
  mpvpaper "${WALL_OUTPUT:-*}" -o "--load-scripts=no --no-audio --loop --panscan=1.0" "$FILE" >/dev/null 2>&1 &
  ln -sf "$FILE" "$WALLPAPER_CURRENT" 2>/dev/null
  write_skwd_state "video"
  [[ -z "$WALL_OUTPUT" ]] && set_startup_mode_video
else
  ensure_state_dirs
  if ! detect_wall_backend; then
    echo "ERROR: no se encontro backend de wallpaper para imagenes (swww/awww)" >&2
    exit 1
  fi
  kill_for_image

  if [[ "$PREV_TYPE" == "video" || "$PREV_TYPE" == "we" ]]; then
    restart_wall_backend
  fi

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

  APPLY_PARAMS="$SWWW_PARAMS"
  if [[ "$PREV_TYPE" == "video" || "$PREV_TYPE" == "we" ]]; then
    APPLY_PARAMS="--transition-type none --transition-duration 0"
  fi

  if ! apply_static_once "$FILE" "$APPLY_PARAMS"; then
    echo "ERROR: fallo al aplicar imagen: $FILE" >&2
    exit 1
  fi

  FORCE_SETTLE=0
  if [[ "$PREV_TYPE" == "video" || "$PREV_TYPE" == "we" ]]; then
    FORCE_SETTLE=1
  fi
  ensure_static_applied "$FILE" "$FORCE_SETTLE"

  ln -sf "$FILE" "$WALLPAPER_CURRENT" 2>/dev/null
  ln -sf "$FILE" "$HOME/.config/rofi/.current_wallpaper" 2>/dev/null
  write_skwd_state "static"
  [[ -z "$WALL_OUTPUT" ]] && set_startup_mode_image
fi

# set_startup_mode_* modifica Startup_Apps.conf → Hyprland recarga → pierde keyword overrides.
# Re-aplicar estado de optimizacion despues de que Hyprland asiente.
if [ -x "$HOME/.config/hypr/scripts/ApplyOptimizationState.sh" ]; then
  nohup "$HOME/.config/hypr/scripts/ApplyOptimizationState.sh" --defer >/dev/null 2>&1 &
fi

