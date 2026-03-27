#!/bin/bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
# Script para alternar aleatoriamente entre fondos de pantalla ESTATICOS y ANIMADOS
# Uso: WallpaperAutoChangeMixed.sh <directorio_de_fondos>

# Prevent multiple instances
PIDFILE="/tmp/wallpaper_auto_change_mixed.pid"
if [ -f "$PIDFILE" ]; then
    if kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
        echo "Script is already running with PID $(cat "$PIDFILE")"
        exit 1
    else
        rm -f "$PIDFILE"
    fi
fi
echo $$ > "$PIDFILE"

# Cleanup on exit
trap 'rm -f "$PIDFILE"; pkill mpvpaper 2>/dev/null; exit' INT TERM EXIT

# Control de señales
SKIP_FLAG=false
RESET_FLAG=false
SLEEP_PID=""

handle_skip() {
    SKIP_FLAG=true
    [[ -n "$SLEEP_PID" ]] && kill "$SLEEP_PID" 2>/dev/null
}

handle_reset() {
    RESET_FLAG=true
    [[ -n "$SLEEP_PID" ]] && kill "$SLEEP_PID" 2>/dev/null
}

trap 'handle_skip' SIGUSR1   # Señal para saltar al siguiente wallpaper
trap 'handle_reset' SIGUSR2  # Señal para reiniciar el temporizador

# Configuración
SCRIPTSDIR=$HOME/.config/hypr/scripts
UserScripts=$HOME/.config/hypr/UserScripts
wallust_refresh=$HOME/.config/hypr/scripts/RefreshNoWaybar.sh

focused_monitor=$(hyprctl monitors | awk '/^Monitor/{name=$2} /focused: yes/{print name}')

if [[ $# -lt 1 ]] || [[ ! -d $1 ]]; then
	echo "Uso:"
	echo "  $0 <directorio con imágenes y videos>"
	exit 1
fi

# Intervalo de cambio (en segundos)
INTERVAL=1800  # 30 minutos
# INTERVAL=900  # 15 minutos
# INTERVAL=300  # 5 minutos (descomenta para usar)
# INTERVAL=60   # 1 minuto (descomenta para usar)
# INTERVAL=10   # 30 Segundos (descomenta para probar)

# Transiciones para imágenes (swww)
export SWWW_TRANSITION_FPS=60
export SWWW_TRANSITION_TYPE=simple
SWWW_PARAMS="--transition-fps $SWWW_TRANSITION_FPS --transition-type $SWWW_TRANSITION_TYPE"

# Función para matar procesos de wallpaper
kill_all_wallpaper_daemons() {
    pkill mpvpaper 2>/dev/null
    pkill swaybg 2>/dev/null
    pkill hyprpaper 2>/dev/null
}

# Función para aplicar imagen estática
apply_static_wallpaper() {
    local image_path="$1"
    
    # Verificar que el archivo existe
    if [[ ! -f "$image_path" ]]; then
        echo "⚠️  ERROR: Archivo no encontrado: $image_path"
        return 1
    fi
    
    # Matar mpvpaper si está corriendo
    kill_all_wallpaper_daemons
    sleep 0.3
    
    # Asegurar que swww-daemon está corriendo
    if ! pgrep -x "swww-daemon" >/dev/null; then
        echo "  → Iniciando swww-daemon..."
        swww-daemon --format xrgb >/dev/null 2>&1 &
        sleep 1
    fi
    
    # Aplicar imagen
    swww img -o "$focused_monitor" "$image_path" $SWWW_PARAMS 2>/dev/null
    
    # Regenerar colores y refrescar UI (solo para imágenes)
    "$SCRIPTSDIR/WallustSwww.sh" "$image_path" >/dev/null 2>&1
    sleep 0.5
    "$wallust_refresh" >/dev/null 2>&1
}

# Función para aplicar video animado
apply_animated_wallpaper() {
    local video_path="$1"
    
    # Verificar que el archivo existe
    if [[ ! -f "$video_path" ]]; then
        echo "⚠️  ERROR: Video no encontrado: $video_path"
        return 1
    fi
    
    # Verificar que mpvpaper está instalado
    if ! command -v mpvpaper &>/dev/null; then
        echo "⚠️  ERROR: mpvpaper no está instalado"
        return 1
    fi
    
    # Matar swww y otros daemons
    pkill -9 swww-daemon 2>/dev/null
    swww kill 2>/dev/null
    kill_all_wallpaper_daemons
    sleep 0.5
    
    # Aplicar video (redirigir salida para evitar spam)
    mpvpaper '*' -o "--load-scripts=no --no-audio --loop" "$video_path" >/dev/null 2>&1 &
    
    # Esperar un poco para que mpvpaper se inicialice
    sleep 1
}

# Detectar tipo de archivo
is_video() {
    local file="${1,,}"  # lowercase para case-insensitive
    [[ "$file" =~ \.(mp4|mkv|mov|webm|avi|flv|wmv|m4v)$ ]]
}

is_image() {
    local file="${1,,}"  # lowercase para case-insensitive
    [[ "$file" =~ \.(jpg|jpeg|png|webp|bmp|gif|tga|tiff|pnm|farbfeld)$ ]]
}

echo "=== Iniciando cambio automático de wallpapers (mixto) ==="
echo "Directorio: $1"
echo "Intervalo: $INTERVAL segundos"

while true; do
    # Recopilar TODOS los archivos (imágenes Y videos) y mezclarlos aleatoriamente
    # Usar -print0 para manejar correctamente archivos con espacios
    mapfile -d '' all_files < <(
        find "$1" -type f \( \
            -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.bmp" -o -iname "*.gif" \
            -o -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.mov" -o -iname "*.webm" -o -iname "*.avi" \
        \) -print0 | shuf -z
    )
    
    if [ ${#all_files[@]} -eq 0 ]; then
        echo "❌ ERROR: No se encontraron imágenes ni videos en $1"
        exit 1
    fi
    
    num_videos=0; num_images=0
    for f in "${all_files[@]}"; do
        if is_video "$f"; then
            ((num_videos++))
        elif is_image "$f"; then
            ((num_images++))
        fi
    done
    echo "📁 Encontrados ${#all_files[@]} archivos → 🖼️  $num_images imágenes, 🎬 $num_videos videos"
    
    for file in "${all_files[@]}"; do
        # Verificar si el script debe detenerse
        if [ ! -f "$PIDFILE" ]; then
            echo "🛑 PIDFILE eliminado, deteniendo..."
            exit 0
        fi
        
        # Saltar archivos que no existen (por si se borraron durante la ejecución)
        if [[ ! -f "$file" ]]; then
            echo "⚠️  Archivo omitido (no existe): $(basename "$file")"
            continue
        fi
        
        # Determinar tipo y aplicar
        if is_video "$file"; then
            echo "🎬 VIDEO: $(basename "$file")"
            apply_animated_wallpaper "$file"
        elif is_image "$file"; then
            echo "🖼️  IMAGEN: $(basename "$file")"
            apply_static_wallpaper "$file"
        else
            echo "⚠️  Archivo no reconocido: $(basename "$file")"
            continue
        fi
        
        # Esperar el intervalo (interrumpible con SIGUSR1 para saltar, SIGUSR2 para reiniciar)
        SKIP_FLAG=false
        RESET_FLAG=false
        while true; do
            sleep "$INTERVAL" &
            SLEEP_PID=$!
            wait $SLEEP_PID 2>/dev/null
            SLEEP_PID=""
            if $RESET_FLAG; then
                echo "🔄 Temporizador reiniciado para: $(basename "$file")"
                RESET_FLAG=false
                continue  # vuelve a dormir otros $INTERVAL segundos
            fi
            break  # salir del bucle (ya sea tiempo cumplido o SIGUSR1)
        done
    done
done
