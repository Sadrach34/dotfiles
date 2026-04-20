# Hyprland Configuration (`.config/hypr/`)

Documentación completa de la estructura, archivos y lógica de `.config/hypr/`.

---

## Estructura de Directorios

```
.config/hypr/
├── hyprland.conf              # Entrada principal — sources todo lo demás
├── hypridle.conf              # Daemon de inactividad
├── hyprlock.conf              # Pantalla de bloqueo (< 1080p)
├── hyprlock-2k.conf           # Pantalla de bloqueo (2K+)
├── monitors.conf              # Configuración de monitores (auto-generado por nwg-displays)
├── workspaces.conf            # Reglas de workspaces (auto-generado por nwg-displays)
├── application-style.conf     # Estilo de apps Qt
├── initial-boot.sh            # Setup de primer arranque (se ejecuta una vez)
│
├── configs/
│   └── Keybinds.conf          # Atajos base (no editar — usar UserKeybinds.conf)
│
├── UserConfigs/               # Configuración del usuario (update-safe)
│   ├── 00-Readme
│   ├── 01-UserDefaults.conf
│   ├── ENVariables.conf
│   ├── Laptops.conf
│   ├── LaptopDisplay.conf
│   ├── Startup_Apps.conf
│   ├── UserAnimations.conf
│   ├── UserDecorations.conf
│   ├── UserKeybinds.conf
│   ├── UserSettings.conf
│   ├── WindowRules.conf
│   └── WindowRules-old.conf
│
├── scripts/                   # Scripts del sistema (45+ archivos)
├── UserScripts/               # Scripts del usuario (update-safe)
├── animations/                # Presets de animación (17 archivos .conf)
├── Monitor_Profiles/          # Perfiles de monitor
└── wallust/
    └── wallust-hyprland.conf  # Paleta de colores (auto-generado por wallust/matugen)
```

---

## Flujo de Carga

```
hyprland.conf
  │
  ├── source wallust/wallust-hyprland.conf     # colores
  ├── source monitors.conf
  ├── source workspaces.conf
  ├── source configs/Keybinds.conf             # keybinds base
  ├── source UserConfigs/ENVariables.conf
  ├── source UserConfigs/Startup_Apps.conf
  ├── source UserConfigs/UserSettings.conf
  ├── source UserConfigs/UserDecorations.conf
  ├── source UserConfigs/UserAnimations.conf
  ├── source UserConfigs/UserKeybinds.conf
  ├── source UserConfigs/WindowRules.conf
  ├── source UserConfigs/01-UserDefaults.conf
  └── exec-once initial-boot.sh               # solo primer arranque
```

---

## Archivos Principales

### `hyprland.conf` — Entrada Principal

Punto de entrada. No contiene configuración directa — solo `source` a los demás archivos. Estructura que permite separar responsabilidades y hacer que `UserConfigs/` sea seguro para actualizaciones.

### `hypridle.conf` — Daemon de Inactividad

| Tiempo | Acción |
|--------|--------|
| 9 min (540s) | Notificación de inactividad |
| 10 min (600s) | Bloqueo de pantalla (`hyprlock`) |
| 10.5 min | Apagar pantalla (opcional) |
| 20 min | Suspender sistema (opcional) |

### `hyprlock.conf` / `hyprlock-2k.conf` — Pantalla de Bloqueo

Dos variantes según resolución. Ambas muestran:
- Wallpaper actual con efecto blur
- Reloj digital (horas, minutos, segundos)
- Fecha, usuario, uptime, batería, clima
- Campo de contraseña con puntos
- Indicador de layout de teclado
- Colores desde `wallust-hyprland.conf`

### `monitors.conf` — Monitores

Auto-generado por `nwg-displays`. Por defecto:
```ini
monitor=,preferred,auto,1    # resolución preferida
monitor=,highrr,auto,1       # high refresh rate
monitor=,highres,auto,1      # alta resolución
```
No editar manualmente — usar `nwg-displays` en su lugar.

### `wallust/wallust-hyprland.conf` — Paleta de Colores

Auto-generado por matugen/wallust al cambiar wallpaper. Define variables como `$color0`–`$color18`, `$background`, `$foreground`. Estas variables son usadas por decoraciones, borders y hyprlock.

---

## UserConfigs/ — Configuración del Usuario

Estos archivos son **update-safe**: el script `install.sh` no los sobreescribe.

### `01-UserDefaults.conf`

Define variables globales de aplicaciones por defecto:

```ini
$edit   = ${EDITOR:-nano}                              # editor de texto
$term   = kitty                                        # terminal
$files  = thunar                                       # gestor de archivos
$Search_Engine = "https://www.google.com/search?q={}" # buscador web
```

### `ENVariables.conf`

Variables de entorno para Wayland/Hyprland:

| Variable | Valor | Propósito |
|----------|-------|-----------|
| `GDK_BACKEND` | `wayland,x11,*` | Backend GTK |
| `QT_QPA_PLATFORM` | `wayland;xcb` | Backend Qt |
| `XDG_CURRENT_DESKTOP` | `Hyprland` | Identidad de escritorio |
| `QT_QPA_PLATFORMTHEME` | `qt6ct` | Tema Qt |
| `XCURSOR_THEME` | `Bibata-Modern-Ice` | Cursor |
| `XCURSOR_SIZE` | `24` | Tamaño de cursor |
| `MOZ_ENABLE_WAYLAND` | `1` | Firefox en Wayland |
| `ELECTRON_OZONE_PLATFORM_HINT` | `auto` | Electron en Wayland |

Variables para Nvidia están comentadas — descomentar si se usa GPU Nvidia.

### `Startup_Apps.conf`

Aplicaciones y servicios que arrancan con Hyprland:

```ini
exec-once = swww-daemon                          # daemon de wallpaper
exec-once = dbus-update-activation-environment  # sincronización de entorno
exec-once = /usr/lib/xdg-desktop-portal-hyprland
exec-once = $scriptsDir/Polkit.sh               # agente de autenticación
exec-once = nm-applet --indicator               # bandeja de red
exec-once = swaync                              # notificaciones
exec-once = waybar                              # barra de estado
exec-once = $UserScripts/StartQuickshell.sh     # shell UI
exec-once = $scriptsDir/PowerProfileAuto.sh     # perfil de energía
exec-once = $UserScripts/RainbowBorders.sh      # bordes animados
exec-once = hypridle                            # daemon de inactividad
exec-once = $UserScripts/PortalRestart.sh       # restart portal (screen share fix)
```

### `UserSettings.conf`

Configuración principal del comportamiento de Hyprland:

**Layouts:**
- Por defecto: `dwindle` (tiling automático)
- Alternativo: `master`
- Scrolling layout: `scroller` con column_width = 1.0

**Input:**
```ini
kb_layout = us,latam      # US + Latinoamérica
repeat_rate = 50
repeat_delay = 300
sensitivity = 0            # mouse sin aceleración
numlock_by_default = true
follow_mouse = 1
```

**Misc:**
```ini
vfr = true                 # variable frame rate (ahorra recursos)
vrr = 2                    # adaptive sync
mouse_move_enables_dpms = true
keyboard_is_focus_not_activate = true  # no robar foco al activar app
```

**XWayland:**
```ini
enabled = true
use_nearest_neighbor = false
force_zero_scaling = true  # fix para escalado en apps XWayland
```

### `UserDecorations.conf`

Estética visual:

```ini
# General
border_size = 2
gaps_in = 2
gaps_out = 4
col.active_border = $color12    # color del borde activo (desde wallust)
col.inactive_border = $color10

# Decoration
rounding = 10               # bordes redondeados
active_opacity = 1.0
inactive_opacity = 0.9
dim_inactive = true
dim_strength = 0.1

# Blur
enabled = true
size = 6
passes = 2
special = true
popups = true

# Shadow
enabled = true
range = 3
render_power = 1
```

### `UserAnimations.conf`

Curvas y tiempos de animación:

```ini
bezier = wind,    0.05, 0.9, 0.1, 1.05    # suave con rebote
bezier = winIn,   0.1,  1.1, 0.1, 1.1     # entrada elástica
bezier = winOut,  0.3, -0.3, 0.0, 1.0     # salida con overshoot
bezier = liner,   1,   1,   1,  1          # lineal (borders)

animation = windows,          1, 6,  wind,  slide
animation = windowsIn,        1, 6,  winIn, slide
animation = windowsOut,       1, 5,  winOut, slide
animation = workspaces,       1, 5,  wind
animation = specialWorkspace, 1, 5,  wind,  slidevert
animation = border,           1, 1,  liner
animation = borderangle,      1, 30, liner, once
animation = fade,             1, 10, default
```

### `UserKeybinds.conf`

Atajos de usuario. Los más importantes:

| Atajo | Acción |
|-------|--------|
| `Super + Space` | App launcher (Quickshell) |
| `Super + K` | Panel de configuración |
| `Super + Return` | Terminal (kitty) |
| `Super + Shift + Return` | Terminal flotante |
| `Super + E` | Gestor de archivos |
| `Super + F` | Firefox |
| `Super + W` | WhatsApp |
| `Super + H` | Ayuda / keybinds cheatsheet |
| `Super + G` | Game mode toggle |
| `Super + N` | Panel de notificaciones |
| `Super + Tab` | Switcher de ventanas |
| `Alt + F4` | Cerrar ventana |
| `Super + ←/→/↑/↓` | Cambiar workspace |
| `Ctrl + Super + ←/→/↑/↓` | Mover ventana a workspace |
| `Super + Shift + S` | Captura de pantalla (Quickshell) |
| `Ctrl + Super + W` | Selector de wallpaper |
| `Ctrl + Alt + W` | Wallpaper aleatorio |
| `Alt + Space` | Cambiar layout de teclado |
| `Ctrl + Alt + L` | Bloquear pantalla |
| `Ctrl + Alt + P` | Menú de energía |

### `WindowRules.conf`

Sistema de tags y reglas de ventanas (sintaxis v3):

**Tags definidos:**
```
browser, notif, terminal, email, projects, screenshare,
im, games, gamestore, file-manager, wallpaper, multimedia,
settings, viewer
```

**Asignación a workspaces:**
| App/Tag | Workspace |
|---------|-----------|
| Email, Browser | 1 |
| Mensajería (IM) | 4 |
| Game store | 5 |
| Juegos | 8 |
| Multimedia | 9 |

**Reglas especiales:**
- Terminal flotante: 60%×60%, centrado, opacidad 0.85
- Picture-in-Picture: anclado a esquina (72% 7%), opacidad 1.1, aspect ratio fijo
- Videos: blur desactivado, pantalla completa
- Layer rules: blur para rofi, swaync, quickshell

### `configs/Keybinds.conf`

Atajos base (no editar — usar `UserKeybinds.conf` para añadir/sobrescribir):

| Atajo | Acción |
|-------|--------|
| `Super + Print` | Screenshot inmediato |
| `Shift + Super + Print` | Screenshot de área |
| `Ctrl + Super + Print` | Screenshot con 5s delay |
| `Ctrl + Alt + Delete` | Salir de Hyprland |
| `Super + 1-9,0` | Cambiar a workspace N |
| `Shift + Super + 1-9,0` | Mover ventana a workspace N |
| `Super + D` | Toggle workspace especial |
| `Super + J/K` | Ciclar ventanas (layout master) |

---

## scripts/ — Scripts del Sistema

Scripts internos usados por keybinds y módulos. **No editar** — usar `UserScripts/` para customizaciones.

### `Volume.sh`
Controla volumen con `pamixer`. Soporta boost hasta 150%. Muestra notificación con ícono según nivel.

```bash
# Uso desde keybind:
$scriptsDir/Volume.sh --inc    # +5%
$scriptsDir/Volume.sh --dec    # -5%
$scriptsDir/Volume.sh --toggle # mute
$scriptsDir/Volume.sh --mic-toggle
```

### `Brightness.sh`
Controla brillo con `brightnessctl`. Rango: 5%–100%. Pasos de 10%.

```bash
$scriptsDir/Brightness.sh --inc
$scriptsDir/Brightness.sh --dec
```

### `ScreenShot.sh`
Capturas con `grim`. Guarda en `~/Pictures/Screenshots/`, copia al portapapeles, muestra notificación con acciones (abrir / eliminar).

```bash
$scriptsDir/ScreenShot.sh --now           # inmediato
$scriptsDir/ScreenShot.sh --area          # selección
$scriptsDir/ScreenShot.sh --in5           # 5s delay
$scriptsDir/ScreenShot.sh --in10          # 10s delay
$scriptsDir/ScreenShot.sh --active        # ventana activa
```

### `GameMode.sh`
Toggle de modo gaming. Deshabilita animaciones, blur, sombras, dimming. Mata Quickshell, wallpaper engine, daemons innecesarios. Oculta Waybar. Pausa notificaciones. Restaura todo al desactivar.

```bash
$scriptsDir/GameMode.sh
```

### `MediaCtrl.sh`
Control de reproducción con `playerctl`.

```bash
$scriptsDir/MediaCtrl.sh --play   # play/pause
$scriptsDir/MediaCtrl.sh --next
$scriptsDir/MediaCtrl.sh --prev
$scriptsDir/MediaCtrl.sh --stop
```

### `LockScreen.sh`
Bloquea con `loginctl lock-session` (o `hyprlock` como fallback).

### `Wlogout.sh`
Abre menú de energía. Ajusta tamaño de botones según resolución de pantalla.

### `ChangeLayout.sh`
Toggle entre layouts `master` y `dwindle`. Ajusta keybinds automáticamente según el layout activo.

### `Animations.sh`
Muestra menú rofi con los 17 presets de animación. Al seleccionar, copia el preset a `UserConfigs/UserAnimations.conf`.

### `ClipManager.sh`
Historial de portapapeles con `cliphist` + rofi. `Ctrl+Delete` elimina entrada, `Alt+Delete` limpia todo.

### `SwitchKeyboardLayout.sh`
Cicla entre los layouts definidos en `UserSettings.conf` (`kb_layout`). Aplica a todos los teclados excepto los ignorados.

### `Refresh.sh`
Reinicia waybar, rofi, swaync y quickshell. Recarga rainbow borders si está activo.

### `RofiSearch.sh`
Búsqueda web desde rofi usando el motor definido en `01-UserDefaults.conf`.

---

## UserScripts/ — Scripts del Usuario

Update-safe. Scripts personalizables por el usuario.

### Wallpaper Scripts

| Script | Función |
|--------|---------|
| `WallpaperRandom.sh` | Wallpaper aleatorio (evita repetir, caché 20s) |
| `WallpaperNext.sh` | Siguiente wallpaper en secuencia |
| `WallpaperApply.sh` | Aplicar wallpaper (imagen/video/wallpaper engine) |
| `WallpaperSelect.sh` | Menú interactivo de selección |
| `WallpaperAutoChange.sh` | Rotación automática por timer |

`WallpaperRandom.sh` tiene lógica avanzada: soporta imágenes estáticas, videos y Steam Workshop wallpapers. Integra con el estado de `skwd-wall`.

### `RainbowBorders.sh`
Efecto de bordes animados con colores dinámicos. Se ejecuta en background desde `Startup_Apps.conf`.

### `StartQuickshell.sh`
Lanza Quickshell (la shell UI principal). Usado en startup.

### `PortalRestart.sh`
Reinicia `xdg-desktop-portal-hyprland`. Fix para screen sharing que a veces falla en el primer arranque.

### Rofi Utilities

| Script | Función |
|--------|---------|
| `RofiBeats.sh` | Reproductor de música online |
| `RofiSSH.sh` | Cliente SSH |
| `RofiCalc.sh` | Calculadora (qalculate) |

### `Weather.sh` / `Weather.py`
Muestra información del clima. Cachea resultado en `~/.cache/.weather_cache`.

---

## animations/ — Presets de Animación

17 archivos `.conf` con configuraciones completas de animación. Se seleccionan vía `scripts/Animations.sh` (menú rofi).

| Preset | Estilo |
|--------|--------|
| `00-default.conf` | Default suave |
| `03- Disable Animation.conf` | Sin animaciones |
| `ML4W - standard/fast/high/classic/dynamic/moving` | Variantes ML4W |
| `HYDE - default/minimal-1/minimal-2/optimized/Vertical` | Variantes HYDE |
| `END-4.conf` | Estilo END-4 |
| `Mahaveer - me-1/me-2` | Estilo Mahaveer |

Cada preset define curvas bezier personalizadas y tiempos para windows, borders, fade, workspaces.

---

## initial-boot.sh — Setup de Primer Arranque

Se ejecuta una sola vez (verifica `~/.config/hypr/.initial_startup_done`):

1. Inicializa wallust/matugen para generar colores
2. Aplica wallpaper con `swww`
3. Configura tema GTK (modo oscuro)
4. Aplica temas de iconos y cursor
5. Configura tema Kvantum (Qt)
6. Crea archivo marcador para no re-ejecutarse

---

## Separación Base vs. Usuario

| Directorio | Propósito | ¿Se sobreescribe en update? |
|------------|-----------|----------------------------|
| `configs/` | Keybinds base | Sí |
| `scripts/` | Scripts del sistema | Sí |
| `animations/` | Presets de animación | Sí |
| `UserConfigs/` | Config del usuario | **No** |
| `UserScripts/` | Scripts del usuario | **No** |

Esta separación permite actualizar los dotfiles con `install.sh --update` sin perder personalizaciones.

---

## Variables Globales Importantes

Definidas en `hyprland.conf` y usadas en toda la configuración:

```ini
$scriptsDir  = ~/.config/hypr/scripts
$UserScripts = ~/.config/hypr/UserScripts
$configs     = ~/.config/hypr/configs
$UserConfigs = ~/.config/hypr/UserConfigs
```
