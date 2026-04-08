#!/bin/bash
# /* ---- 💫 Script de Modo Juego Mejorado y Sincronizado ---- */

# --- CONFIGURACIÓN ---
# ¡Valores extraídos de tu UserDecorations.conf!
GAPS_IN=2
GAPS_OUT=4
BORDER_SIZE=2
ROUNDING=10

# --- RUTAS ---
NOTIF_ICON="$HOME/.config/swaync/images/ja.png"
WALLPAPER="$HOME/.config/rofi/.current_wallpaper" 

# --- LÓGICA ---
LOCK_FILE="/tmp/gamemode.lock"
WALLPAPER_DIR="$HOME/Pictures/wallpapers"

if [ -f "$LOCK_FILE" ]; then
    # --- DESACTIVAR MODO JUEGO ---
    hyprctl --batch "\
        keyword animations:enabled 1;\
        keyword decoration:blur:enabled 1;\
        keyword decoration:shadow:enabled 1;\
        keyword decoration:dim_inactive 1;\
        keyword decoration:active_opacity 1.0;\
        keyword decoration:inactive_opacity 0.9;\
        keyword general:gaps_in $GAPS_IN;\
        keyword general:gaps_out $GAPS_OUT;\
        keyword general:border_size $BORDER_SIZE;\
        keyword decoration:rounding $ROUNDING;\
        keyword misc:vfr 1;\
        keyword misc:vrr 0"

    hyprctl keyword windowrule "opacity,^(.*)$"
    
    # Reanudar swaync (NO matarlo, solo descongelarlo)
    pkill -CONT swaync 2>/dev/null
    
    # Reiniciar waybar solamente
    if pidof waybar >/dev/null; then
        pkill waybar
    fi
    killall -SIGUSR2 waybar 2>/dev/null
    
    sleep 1
    waybar &
    
    # Restaurar wallpaper actual
    # 1. Cargar wallpaper actual si existe (imagen estática)
    if [ -f "$WALLPAPER" ] && [ -s "$WALLPAPER" ]; then
        # Asegurar que swww-daemon está corriendo
        if ! pgrep -x swww-daemon >/dev/null; then
            swww-daemon --format xrgb >/dev/null 2>&1 &
            sleep 1
        fi
        swww img "$WALLPAPER" >/dev/null 2>&1
    fi
    
    rm "$LOCK_FILE"
    notify-send -u normal -i "$NOTIF_ICON" "🎮 Modo Juego: Desactivado" "Configuración visual restaurada.\n✅ Efectos reactivados\n✅ Notificaciones activas"
else
    # --- ACTIVAR MODO JUEGO ---
    touch "$LOCK_FILE"
    hyprctl --batch "\
        keyword animations:enabled 0;\
        keyword decoration:blur:enabled 0;\
        keyword decoration:shadow:enabled 0;\
        keyword decoration:dim_inactive 0;\
        keyword decoration:active_opacity 1.0;\
        keyword decoration:inactive_opacity 1.0;\
        keyword general:gaps_in 0;\
        keyword general:gaps_out 0;\
        keyword general:border_size 1;\
        keyword decoration:rounding 0;\
        keyword misc:vfr 0;\
        keyword misc:vrr 2"
    
    # Ocultar Waybar
    pkill -USR1 waybar
    
    # Pausar/matar notificaciones (swaync)
    pkill -STOP swaync 2>/dev/null
    
    # Matar procesos de wallpaper que consumen recursos
    pkill -9 mpvpaper 2>/dev/null  # Videos animados
    swww kill 2>/dev/null          # Daemon de imágenes
    
    # Opcional: Pausar otros daemons innecesarios
    # pkill -STOP rog-control-center 2>/dev/null
    
    notify-send -u low -i "$NOTIF_ICON" "🎮 Modo Juego: Activado" "Máximo rendimiento activado.\n⚡ Animaciones OFF\n⚡ Blur/Sombras OFF\n⚡ Notificaciones pausadas\n⚡ VRR activado"
fi