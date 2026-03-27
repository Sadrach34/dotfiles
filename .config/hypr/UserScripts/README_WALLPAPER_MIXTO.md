# 🎬 Guía: Fondos de Pantalla Mixtos (Estáticos + Animados)

## ✅ ¿Qué hace este script?

El script `WallpaperAutoChangeMixed.sh` permite alternar **aleatoriamente** entre:

- 🖼️ **Imágenes estáticas** (.jpg, .png, .webp, etc.) usando `swww`
- 🎬 **Videos animados** (.mp4, .mkv, .webm, etc.) usando `mpvpaper`

## 📋 Requisitos

Asegúrate de tener instalados:

```bash
sudo pacman -S swww mpvpaper
# o con yay/paru si no están en repos oficiales:
yay -S swww-git mpvpaper
```

## 🚀 Cómo usar

### Opción 1: Ejecutar manualmente

```bash
~/.config/hypr/UserScripts/WallpaperAutoChangeMixed.sh ~/Pictures/wallpapers
```

### Opción 2: Auto-inicio (recomendado)

Edita tu archivo de configuración:

```bash
nano ~/.config/hypr/UserConfigs/Startup_Apps.conf
```

**CAMBIA:**

```conf
exec-once = $SwwwRandom $wallDIR
```

**POR:**

```conf
$SwwwRandomMixed = $UserScripts/WallpaperAutoChangeMixed.sh
exec-once = $SwwwRandomMixed $wallDIR
```

O **comenta** la línea anterior y agrega:

```conf
# exec-once = $SwwwRandom $wallDIR  # Desactivado: solo imágenes
exec-once = $HOME/.config/hypr/UserScripts/WallpaperAutoChangeMixed.sh $wallDIR
```

## ⚙️ Configuración

### Cambiar el intervalo de tiempo

Edita el archivo:

```bash
nano ~/.config/hypr/UserScripts/WallpaperAutoChangeMixed.sh
```

Busca la línea:

```bash
INTERVAL=900  # 15 minutos
```

Opciones:

```bash
INTERVAL=1800  # 30 minutos
INTERVAL=900   # 15 minutos
INTERVAL=300   # 5 minutos
INTERVAL=60    # 1 minuto (para probar)
```

## 📁 Organización de archivos

Puedes mezclar imágenes y videos en el **mismo directorio**:

```
~/Pictures/wallpapers/
├── imagen1.jpg
├── imagen2.png
├── video1.mp4
├── paisaje.webp
├── animado.webm
└── ...
```

O crear subdirectorios (el script los encontrará recursivamente):

```
~/Pictures/wallpapers/
├── Estaticos/
│   ├── imagen1.jpg
│   └── imagen2.png
└── Animados/
    ├── video1.mp4
    └── video2.webm
```

## 🛠️ Solución de problemas

### El script no cambia los wallpapers

```bash
# Verificar si el script está corriendo
ps aux | grep WallpaperAutoChangeMixed

# Detener instancias antiguas
pkill -f WallpaperAutoChangeMixed

# Ejecutar manualmente para ver errores
~/.config/hypr/UserScripts/WallpaperAutoChangeMixed.sh ~/Pictures/wallpapers
```

### mpvpaper no funciona

```bash
# Verificar instalación
which mpvpaper

# Si no está instalado:
yay -S mpvpaper
```

### swww no cambia imágenes

```bash
# Reiniciar swww-daemon
killall swww-daemon
swww-daemon --format xrgb &
```

### Detener el script

```bash
rm /tmp/wallpaper_auto_change_mixed.pid
pkill -f WallpaperAutoChangeMixed
```

## 🎯 Formatos soportados

### Imágenes (swww):

- .jpg, .jpeg
- .png
- .webp
- .bmp
- .gif
- .tga, .tiff, .pnm, .farbfeld

### Videos (mpvpaper):

- .mp4
- .mkv
- .webm
- .mov
- .avi, .flv, .wmv, .m4v

## 📝 Notas importantes

1. **Los videos NO regeneran colores**: Solo las imágenes estáticas actualizan los colores de Wallust/Waybar. Esto es una limitación técnica.

2. **Consumo de recursos**: Los videos consumen más CPU/GPU que las imágenes estáticas.

3. **Un solo monitor**: El script usa el monitor enfocado (`focused_monitor`). Para multi-monitor, necesitarías modificar el script.

4. **No mezclar con el script original**: No ejecutes `WallpaperAutoChange.sh` y `WallpaperAutoChangeMixed.sh` al mismo tiempo.

## 🔄 Volver al modo solo imágenes

Si prefieres volver al script original (solo imágenes):

1. Edita `~/.config/hypr/UserConfigs/Startup_Apps.conf`
2. Comenta o elimina la línea del script mixto
3. Descomenta la línea original:

```conf
exec-once = $SwwwRandom $wallDIR
```

4. Reinicia Hyprland o ejecuta:

```bash
~/.config/hypr/UserScripts/WallpaperAutoChange.sh ~/Pictures/wallpapers &
```

---

**Autor**: Basado en JaKooLit's Hyprland-Dots  
**Fecha**: Enero 2026
