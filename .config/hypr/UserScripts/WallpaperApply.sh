#!/bin/bash
# /* ---- WallpaperApply.sh ---- */
# Llamado desde el QS WallpaperPicker para aplicar fondos.
# Recibe: $1 = tipo ("video" | "image")  $2 = ruta completa al archivo

TYPE="$1"
FILE="$2"
WALLPAPER_CURRENT="$HOME/.config/hypr/wallpaper_effects/.wallpaper_current"

FPS=60
TTYPE="any"
DURATION=2
BEZIER=".43,1.19,1,.4"
SWWW_PARAMS="--transition-fps $FPS --transition-type $TTYPE --transition-duration $DURATION --transition-bezier $BEZIER"

kill_for_video() {
  swww kill 2>/dev/null
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
  kill_for_video
  mpvpaper '*' -o "load-scripts=no no-audio --loop --panscan=1.0" "$FILE" &
  ln -sf "$FILE" "$WALLPAPER_CURRENT" 2>/dev/null
  # Modificar Startup_Apps para persistencia
  STARTUP="$HOME/.config/hypr/UserConfigs/Startup_Apps.conf"
  if [[ -f "$STARTUP" ]]; then
    sed -i '/^\s*exec-once\s*=\s*swww-daemon\s*--format\s*xrgb\s*$/s/^/#/' "$STARTUP" 2>/dev/null
    sed -i '/^\s*#\s*exec-once\s*=\s*mpvpaper\s*.*$/s/^#\s*//' "$STARTUP" 2>/dev/null
    ESCAPED_FILE="${FILE/#$HOME/\$HOME}"
    sed -i "s|^\\\$livewallpaper=.*|\$livewallpaper=\"$ESCAPED_FILE\"|" "$STARTUP" 2>/dev/null
  fi
else
  kill_for_image
  if ! pgrep -x swww-daemon >/dev/null; then
    swww-daemon --format xrgb &
    sleep 0.5
  fi
  swww img "$FILE" $SWWW_PARAMS
  ln -sf "$FILE" "$WALLPAPER_CURRENT" 2>/dev/null
  ln -sf "$FILE" "$HOME/.config/rofi/.current_wallpaper" 2>/dev/null
  # Modificar Startup_Apps para persistencia
  STARTUP="$HOME/.config/hypr/UserConfigs/Startup_Apps.conf"
  if [[ -f "$STARTUP" ]]; then
    sed -i '/^\s*#\s*exec-once\s*=\s*swww-daemon\s*--format\s*xrgb\s*$/s/^\s*#\s*//' "$STARTUP" 2>/dev/null
    sed -i '/^\s*exec-once\s*=\s*mpvpaper\s*.*$/s/^/#/' "$STARTUP" 2>/dev/null
  fi
fi

# Reiniciar temporizador de auto-cambio de wallpaper (si está corriendo)
AUTO_PIDFILE="/tmp/wallpaper_auto_change_mixed.pid"
if [[ -f "$AUTO_PIDFILE" ]]; then
  AUTO_PID=$(cat "$AUTO_PIDFILE")
  if kill -0 "$AUTO_PID" 2>/dev/null; then
    kill -USR2 "$AUTO_PID" 2>/dev/null
  fi
fi
