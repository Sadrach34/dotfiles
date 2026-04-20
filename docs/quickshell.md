# QuickShell Configuration

> Config path: `.config/quickshell/`

## Overview

QuickShell is the primary desktop UI overlay, built with QML on top of Wayland. It provides all the interactive panels that sit above Waybar: a right-side dashboard, a dropdown top panel, a full-screen app launcher, a window switcher, a wallpaper picker, and a screenshot tool. All panels are Wayland layer-shell surfaces managed by a single `shell.qml` root.

---

## Directory Structure

```
.config/quickshell/
├── shell.qml                  # Entry point — instantiates all panels
├── components/                # All UI components
│   ├── AppLauncher.qml        # Full-screen parallelogram launcher (976 lines)
│   ├── AppLauncherService.qml # App data + frequency ranking (359 lines)
│   ├── Dashboard.qml          # Right sidebar (139 lines)
│   ├── TopPanel.qml           # 5-tab dropdown panel (1900 lines)
│   ├── WindowSwitcher.qml     # Alt-Tab switcher (695 lines)
│   ├── WindowSwitcherService.qml
│   ├── NotificationToast.qml  # Floating toast (178 lines)
│   ├── WallpaperPicker.qml
│   ├── ClickOverlay.qml       # Dismiss-on-click outside panels
│   ├── ModernClock.qml
│   ├── ThemeColorService.qml
│   ├── toppanel/              # TopPanel sub-widgets (8 files, ~3300 lines)
│   ├── dashboard/             # Dashboard sub-widgets (8 files, ~1140 lines)
│   ├── config-panel/          # Settings UI (20+ files)
│   ├── ModernClockWidget/     # Custom clock with bundled fonts
│   └── skwd-wall/             # Wallpaper picker submodule (90+ files)
├── scripts/
│   ├── appvolume_parse.py     # Per-app volume via pactl
│   ├── desktop_apps.py        # .desktop file scanner
│   ├── system_monitor.py      # CPU/RAM/GPU/disk daemon
│   ├── notif_watch.sh         # D-Bus notification watcher
│   ├── python/
│   │   ├── config_panel.py    # GTK4 settings app (1847 lines)
│   │   ├── skwdconfig.py      # Shared config accessor (90 lines)
│   │   └── build-app-cache    # App launcher cache builder (453 lines)
│   └── bash/
│       ├── lib.sh             # Shared env/utility library (121 lines)
│       ├── toggle-config-panel.sh
│       └── wm-action          # Compositor-agnostic WM actions (124 lines)
├── screenshot/                # Screenshot + screenrecord tools
├── data/
│   ├── config.json            # Master user config
│   └── apps.json              # Per-app launcher customization
├── assets/                    # Images, icons
├── images/
└── state/                     # Runtime state (not tracked in git)
```

---

## Entry Point: `shell.qml`

`ShellRoot` is the top-level QML object. Everything instantiated here becomes an independent Wayland surface.

### Fonts Loaded at Startup

```qml
FontLoader { source: "~/.local/share/fonts/Phosphor-Bold.ttf" }
FontLoader { source: "~/.local/share/fonts/Phosphor.ttf" }
// Fallback system paths also loaded
```

Phosphor is the primary icon font used throughout all UI components.

### Global Visibility Flags

| Property | Default | Controls |
|----------|---------|---------|
| `dashboardVisible` | `false` | Right sidebar |
| `topPanelVisible` | `false` | 5-tab dropdown |
| `appLauncherVisible` | `false` | Full-screen launcher |
| `windowSwitcherVisible` | `false` | Alt-Tab switcher |
| `wallpaperPickerVisible` | `false` | Wallpaper gallery |

Toggle functions invert each flag. Components read their flag and animate in/out.

### Components Instantiated

```qml
Dashboard {}
TopPanel {}
NotificationToast {}
ClickOverlay {}
AppLauncher { colors: skwdColors; colorService: themeColors }
WindowSwitcher { colors: skwdColors }
WallpaperPicker {}
ModernClock {}
// + Screenshot Variants per screen
// + ScreenrecordTool Loader
// + RecordingIndicator Variants per screen
```

### IPC Handlers

Exposed via `qs ipc call <target> <function>`:

| Target | Function | Action |
|--------|---------|--------|
| `dashboard` | `toggle` | Toggle right sidebar |
| `toppanel` | `toggle` | Toggle 5-tab dropdown |
| `applauncher` | `toggle` | Toggle app launcher |
| `windowswitcher` | `toggle` | Toggle window switcher |
| `wallpaperpicker` | `toggle` | Toggle wallpaper picker |
| `wallpaperpicker` | `open` | Show wallpaper picker |
| `wallpaperpicker` | `close` | Hide wallpaper picker |
| `screenshot` | `toggle` | Toggle screenshot tool |
| `screenrecord` | `toggle` | Toggle screen recorder |

**Usage from Hyprland keybinds:**
```bash
bind = SUPER, D, exec, qs ipc call dashboard toggle
bind = SUPER, A, exec, qs ipc call applauncher toggle
bind = ALT, Tab, exec, qs ipc call windowswitcher toggle
bind = SUPER, W, exec, qs ipc call wallpaperpicker toggle
```

**Usage from Waybar modules (UserModules):**
```bash
if pgrep -x quickshell >/dev/null; then
  qs ipc call dashboard toggle
else
  quickshell >/dev/null 2>&1 & sleep 0.6
  qs ipc call dashboard toggle
fi
```

---

## Color System

### `SkwdTheme.Colors` / `Colors.qml`

Singleton that reads `~/.cache/quickshell/colors.json` (generated by matugen). Hot-reloads on file change via `FileView { watchChanges: true }`.

#### Color Tokens (Material Design 3 palette)

| Token | Default fallback | Role |
|-------|-----------------|------|
| `primary` | `#ffb4ab` | Primary action color |
| `primaryText` | `#690005` | Text on primary |
| `primaryContainer` | `#b12723` | Containers using primary |
| `secondary` | `#ffb4ab` | Secondary elements |
| `secondaryContainer` | `#792f29` | Secondary containers |
| `tertiary` | `#8bceff` | Accent / tertiary |
| `tertiaryContainer` | `#006390` | Tertiary containers |
| `background` | `#1d100e` | Window/panel backgrounds |
| `backgroundText` | `#f7ddd9` | Text on background |
| `surface` | `#1d100e` | Card/surface backgrounds |
| `surfaceVariant` | `#5a413e` | Elevated surfaces |
| `surfaceContainer` | `#2c1f1d` | Container surfaces |
| `error` | `#ffb4ab` | Error states |
| `errorContainer` | `#93000a` | Error containers |
| `outline` | `#a98986` | Borders |
| `shadow` | `#000000` | Drop shadows |
| `inverseSurface` | `#f7ddd9` | Inverted surface (light mode) |
| `inversePrimary` | `#b32824` | Inverted primary |

All colors update atomically when `colors.json` changes — every component bound to `Colors.*` re-renders.

### `ThemeColorService`

Wraps `Colors` and provides derived/computed color values to components that need processed variants (alpha, lighter, darker).

---

## Dashboard (Right Sidebar)

**File:** `components/Dashboard.qml`

Vertical panel that slides in from the right edge.

### Layout

```
Position: right edge
Width:     420px
Visible:   right margin = 6px
Hidden:    right margin = -(420+50)px
Animation: 300ms OutCubic
```

### Widget Stack (top to bottom)

| Widget | File | Contents |
|--------|------|---------|
| ProfileSection | `dashboard/ProfileSection.qml` | Avatar picker, username, uptime |
| PowerBar | `dashboard/PowerBar.qml` | Shutdown, reboot, lock, suspend, logout buttons |
| NotificationsWidget | `dashboard/` | System notification list |
| MusicPlayer | `dashboard/MusicPlayer.qml` | playerctl integration, animated GIF |
| SliderControls | `dashboard/SliderControls.qml` | System volume (wpctl) |
| BatteryWidget | `dashboard/BatteryWidget.qml` | Battery % + charging state |
| SystemStats | `dashboard/SystemStats.qml` | CPU/RAM/disk circular gauges |
| ClockWidget | `dashboard/ClockWidget.qml` | Digital clock + monthly calendar |

Content is `Flickable` — scrolls if it overflows the panel height.

Escape key closes the panel. `WlrLayershell` uses `OnDemand` keyboard focus.

---

## TopPanel (5-Tab Dropdown)

**File:** `components/TopPanel.qml` (1900 lines)

Full-width panel that slides down from the top of the screen.

### Layout

```
Position: top, spanning full width
Height:   500px content + 48px tab bar
Hidden:   margin-top = -(500+12)px
Visible:  margin-top = 48px (below Waybar)
Animation: 300ms OutCubic
```

### Tabs

| # | Icon | Name | Contents |
|---|------|------|---------|
| 0 | `\ueb02` | Apps | FullPlayer + QuickControls + Calendar + Notification history + Clipboard + AppVolumeWidget + VerticalSliders |
| 1 | `\ue6c8` | Fondos | Wallpaper gallery (thumbnails, filters, search, sort) |
| 2 | `\ue2ac` | Métricas | CPU/RAM/disk system monitor (SysResources) |
| 3 | `\ue6a2` | Asistente | AI assistant (Chat UI placeholder) |
| 4 | `\ue63e` | Notas / Volumen | NotesWidget (Markdown) + App volume controls |

Tab indicator uses elastic animation: `fast` property for leading edge (150ms), `slow` for trailing (250ms) — "rubber band" feel.

Visibility of individual tab contents is controlled by `config.json` flags:
- `barMusicEnabled`, `barCalendarEnabled`, `barVolumeEnabled`

### Sub-Widgets

#### `toppanel/FullPlayer.qml` (568 lines)
Full MPRIS music player — cover art, title, artist, progress bar, playback controls. Uses `playerctl`.

#### `toppanel/AmbxstQuickControls.qml` (285 lines)
Quick toggle buttons:
- WiFi toggle
- Bluetooth toggle
- Night Light
- Caffeine (screen inhibit)
- GameMode (via `scxctl` scheduler integration)

#### `toppanel/AmbxstCalendar.qml` (233 lines)
Monthly calendar grid with forward/back navigation.

#### `toppanel/AmbxstNotificationHistory.qml` (443 lines)
Expandable list of past notifications — collapsible per-app groups.

#### `toppanel/AppVolumeWidget.qml` (293 lines)
Per-application volume sliders. Reads from `scripts/appvolume_parse.py` which parses `pactl list sink-inputs`.

#### `toppanel/AmbxstVerticalSliders.qml` (423 lines)
Large vertical sliders for:
- Master system volume (via `wpctl`)
- Screen brightness

#### `toppanel/ClipboardWidget.qml` (241 lines)
Clipboard history using `wl-paste` integration.

#### `toppanel/NotesWidget.qml` (526 lines)
Markdown notes editor — text persisted locally.

---

## AppLauncher

**File:** `components/AppLauncher.qml` (976 lines)
**Service:** `components/AppLauncherService.qml` (359 lines)

Full-screen launcher with parallelogram-slice visual design.

### Visual Design

```
Layout:         horizontal row of parallelogram slices
Slice width:    135px (default), 924px (expanded/selected)
Slice spacing:  -22px (overlapping)
Slice height:   520px
Skew offset:    35px
Filter bar:     50px top
Animation:      expand/collapse on hover/keyboard selection
```

### Source Filters

| Filter | Shows |
|--------|-------|
| All | Everything |
| Apps | Desktop applications |
| Games | Game category apps |
| Steam | Steam library games |

### Search

Live filtering by: `name`, `displayName`, `categories`, `tags`. Results sorted by frequency rank for the current search prefix.

### Frequency Ranking

- Every launch records which app was opened for which search prefix
- Cache: `~/.cache/quickshell/app-launcher/freq.json`
- Apps you use often for a given prefix float to the top

### App Cache

Built by `scripts/python/build-app-cache`:
- Scans `/usr/share/applications` + `~/.local/share/applications`
- Resolves icons via GTK icon theme hierarchy
- Generates 256×256 thumbnails (460×215 for Steam)
- Applies customizations from `data/apps.json`
- Output: `~/.cache/quickshell/app-launcher/list.jsonl` (one JSON object per line)

### Keyboard Navigation

| Key | Action |
|-----|--------|
| Arrow Left/Right | Navigate slices |
| Tab / Backtab | Navigate slices |
| Enter | Launch selected app |
| Escape | Close launcher |

### Category Badges

Each app slice shows a badge: `STEAM`, `GAME`, `DEV`, `GFX`, `MEDIA`, `NET`, `OFFICE`, `SYS`, `CFG`, `UTIL`, `APP`

---

## WindowSwitcher

**File:** `components/WindowSwitcher.qml` (695 lines)
**Service:** `components/WindowSwitcherService.qml` (231 lines)

Alt-Tab window switcher sharing the same parallelogram-slice geometry as AppLauncher.

### Features

- Window screenshots as slice backgrounds (fallback: gradient)
- `FLOAT` badge on floating windows
- `Del` key closes focused window
- Left/Right arrows or scroll wheel to navigate
- Enter to focus, Escape to cancel
- Multi-monitor aware

### Service

`WindowSwitcherService` queries Hyprland for open windows via `hyprctl`. Captures screenshots on demand. Exposes `focusWindow(winId)` and `closeWindow(winId)`.

---

## NotificationToast

**File:** `components/NotificationToast.qml` (178 lines)

Floating toast in the top-right corner.

```
Position:  top-right
Width:     300px
Visible:   margin-right = 10px
Hidden:    margin-right = -(300+20)px
Animation: 300ms slide
Auto-hide: 2.5s timeout
Top margin: 52px (clears Waybar)
```

Data source: `scripts/notif_watch.sh` — monitors D-Bus `org.freedesktop.Notifications` signals, outputs JSON per notification.

Special behavior: if notification body contains a screenshot path, shows camera icon. Click opens file in `swappy`.

---

## WallpaperPicker

Wraps `components/skwd-wall/` — see [Wallpaper System](#wallpaper-system-skwd-wall) below.

---

## Screenshot Tool

**Files:** `screenshot/` directory
**State singleton:** `SsState.screenshotToolVisible` / `SsState.screenRecordToolVisible`

Two Wayland surfaces loaded per screen via `Variants { model: Quickshell.screens }`:

| Component | Lifecycle | Purpose |
|-----------|---------|---------|
| `ScreenshotTool` | `active: SsState.screenshotToolVisible` | Created on toggle, destroyed on close |
| `ScreenshotOverlay` | Always active | Receives `onImageSaved` signal |
| `ScreenrecordTool` | Always loaded | `open()`/`close()` called via IPC |
| `RecordingIndicator` | Active on screen[0] only | Shows recording status badge |

IPC:
```bash
qs ipc call screenshot toggle
qs ipc call screenrecord toggle
```

---

## Config Panel

**File:** `scripts/python/config_panel.py` (1847 lines)

A full GTK4/Adwaita settings application launched by `scripts/bash/toggle-config-panel.sh`.

### Pages

| Page | Contents |
|------|---------|
| General | System info, terminal selection, GPU vendor, paths, Ollama config, Matugen scheme type, performance |
| Screen | Bar backend, Waybar presets, widget toggles, weather city, WiFi interface, music player, MPRIS config |
| Components | App launcher, window switcher, notifications, lockscreen, smart home, power menu, wallpaper selector toggles |
| Power | Device type, power profile |
| Hypridle | Enable daemon, warn/lock timeouts, D-Bus inhibit |
| Integrations | Theme output paths: Kitty, KDE, VSCode, Vesktop, Zen, Spicetify, Yazi, Qt6ct |
| Apps | Per-app: displayName, icon glyph, tags, hidden, custom background |
| Intervals | Poll intervals in ms: weather, WiFi, smart home, Ollama, notifications, system stats fast/slow |
| Startup Apps | Toggle `exec-once` lines in Hyprland config |
| Window Rules | Workspace assignment rules |
| Keybinds | Edit system/user keybinds from `Keybinds.conf` / `UserKeybinds.conf`, enable/disable toggle |

### Behavior

- Reads/writes `data/config.json` directly
- File watcher: shows banner if config changed externally while panel is open
- Side effects on save: Waybar restart, power profile apply, GPU env vars set, `hypridle` restart, keybind reload
- Unsaved-changes detection: Save / Discard / Defaults buttons
- Toast notifications for all operations
- Sidebar search/filter for quick navigation

---

## Wallpaper System (`skwd-wall`)

**Path:** `components/skwd-wall/`
**Type:** Git submodule

Complete wallpaper picker and theming engine.

### Config Singleton (`qml/Config.qml`)

Reads config from (in priority order):
1. `$SKWD_WALL_CONFIG/config.json`
2. `~/.config/quickshell/data/config.json` (fallback)

Hot-reloads on file change. Also reads `$SKWD_WALL_CONFIG/.env` for secrets (API keys).

Key paths resolved by Config:

| Property | Default |
|----------|---------|
| `cacheDir` | `~/.cache/skwd-wall` |
| `wallpaperDir` | `~/Pictures/Wallpapers` |
| `videoDir` | `~/videowalls` |
| `weDir` | `~/.local/share/Steam/steamapps/workshop/content/431960` |
| `scriptsDir` | `<installDir>/scripts` |
| `templateDir` | `<installDir>/data/matugen/templates` |

Feature flags (all default `true` unless specified):

| Flag | Key in config |
|------|--------------|
| `matugenEnabled` | `features.matugen` |
| `ollamaEnabled` | `features.ollama` |
| `steamEnabled` | `features.steam` |
| `wallhavenEnabled` | `features.wallhaven` |
| `videoPreviewEnabled` | `features.videoPreview` |

### Wallpaper Selector Modes

`displayMode` in config:

| Mode | Layout |
|------|--------|
| `slices` | Parallelogram slices (default) |
| `hex` | Hexagonal grid |
| `grid` | Standard thumbnail grid |
| `wallhaven` | Wallhaven browser |

**Slices mode** parameters (auto-adjusts for small screens ≤1600px):

| Setting | Large screen | Small screen |
|---------|-------------|-------------|
| `wallpaperSliceHeight` | 520px | 360px |
| `wallpaperVisibleCount` | 12 | 8 |
| `wallpaperExpandedWidth` | 924px | 600px |
| `wallpaperSliceWidth` | 135px | 90px |
| `wallpaperSliceSpacing` | -30px | -30px |
| `wallpaperSkewOffset` | 35px | 25px |

**Hex mode** parameters:

| Setting | Large | Small |
|---------|-------|-------|
| `hexRadius` | 140px | 100px |
| `hexRows` | 3 | 3 |
| `hexCols` | 7 | 5 |

**Grid mode** parameters:

| Setting | Large | Small |
|---------|-------|-------|
| `gridColumns` | 6 | 4 |
| `gridThumbWidth` | 300px | 220px |
| `gridThumbHeight` | 169px | 124px |

### Auto-Change

| Setting | Key | Default |
|---------|-----|---------|
| Enable auto-change | `wallpaperAutoChangeEnabled` | `false` |
| Mode | `wallpaperAutoChangeMode` | `"random"` (or `"next"`) |
| Interval | `wallpaperAutoChangeIntervalMinutes` | 10 |

### Wallpaper Sources

| Source | How it works |
|--------|-------------|
| Local images | Files in `wallpaperDir` |
| Local videos | Files in `videoDir` |
| Steam Workshop | Browse/download via `SteamWorkshopBrowser.qml` (App ID 431960) |
| Wallhaven | `WallhavenBrowser.qml` — requires API key in config or `.env` |

### `WallpaperApplyService.qml` (477 lines)

Applies wallpaper based on file type:

| File type | Tool |
|-----------|------|
| Static image | `swww img` (via `awww` daemon) |
| Video | `mpvpaper` |
| Steam WE scene | `linux-wallpaperengine` |

On apply:
1. Sets wallpaper via appropriate tool
2. Calls `matugen image <path>` to regenerate color palette
3. Writes new colors to `~/.cache/quickshell/colors.json`
4. `Colors.qml` hot-reloads → all UI updates live
5. Per-app themes regenerated via templates (Kitty, VSCode, Qt6ct, etc.)

Supports: grow transition effects, configurable fps/duration/angle, retry logic for WE scenes.

### Matugen Templates

Located at `skwd-wall/data/matugen/templates/`:

| Template | Output |
|----------|--------|
| `kitty.conf` | `~/.config/kitty/skwd-theme.conf` |
| `kde-colors.colors` | `~/.local/share/color-schemes/SkwdMatugen.colors` |
| `vscode-theme.json` | VSCode extension theme |
| `vesktop.css` | Vesktop theme |
| `zen.css` / `zen-content.css` | Zen browser |
| `spicetify.ini` / `spicetify.css` | Spicetify |
| `yazi-theme.toml` | Yazi file manager |
| `qt6ct-colors.conf` | Qt6 color scheme |
| `niri-colors.kdl` | Niri compositor |
| `ghostty.conf` | Ghostty terminal |
| `quickshell-colors.json` | QuickShell internal |

Reload scripts in `data/matugen/scripts/`:
- `reload-kde.sh` — `kwriteconfig6` + KDE color scheme refresh
- `reload-niri.sh` — Niri config reload
- `reload-spicetify.sh` — Spicetify apply
- `reload-omp.sh` — Oh-My-Posh refresh

### Services

| Service | Role |
|---------|-----|
| `BootstrapService` | Initialization gate — other services wait for `ready: true` |
| `WatcherService` | inotify watching for wallpaper directory changes |
| `DbService` | SQLite cache for wallpaper metadata |
| `ImageService` | Thumbnail generation |
| `ImageOptimizeService` | Image optimization (resize, compress) |
| `VideoConvertService` | Video format conversion |
| `WallpaperCacheService` | Cache management |
| `WallpaperAnalysisService` | Image analysis (dominant colors) |
| `MatugenCacheService` | Matugen color output cache |
| `ColorMapping` | Color palette management |
| `WallpaperApplyService` | Apply selected wallpaper (see above) |
| `FileMetadataService` | File size, dimensions, dates |

---

## Scripts

### Python Scripts

#### `scripts/system_monitor.py` (329 lines)

System stats daemon piped into QuickShell via stdout.

**Startup output (JSON):**
- CPU model
- GPU info: vendor (nvidia/amd/intel), name
- Disk types per mount (SSD/HDD)

**Continuous output (JSON, per poll):**
- `cpu.percent`, `cpu.temp`
- `ram.percent`, `ram.total`, `ram.used`, `ram.available`
- `disk[].mount`, `disk[].percent`
- `gpu.utilization`, `gpu.temp` (via `nvidia-smi` or DRM sysfs)

Graceful `KeyboardInterrupt` handling.

#### `scripts/appvolume_parse.py` (36 lines)

Runs `pactl list sink-inputs`, extracts per-app audio streams.

Output JSON: `[{"index": N, "app": "appname", "volume": 75, "muted": false}, ...]`

Used by `toppanel/AppVolumeWidget.qml`.

#### `scripts/desktop_apps.py` (178 lines)

Scans `.desktop` files and resolves icons via GTK icon theme. Used by `build-app-cache` for the launcher.

- Searches `/usr/share/applications` + `~/.local/share/applications`
- Deduplicates, filters `NoDisplay` / `Hidden` / non-`Application` types
- Resolves icon paths with size+format priority
- Outputs JSON array of app entries

#### `scripts/python/config_panel.py` (1847 lines)

GTK4/Adwaita settings app — see [Config Panel](#config-panel) section.

#### `scripts/python/skwdconfig.py` (90 lines)

Shared Python config reader used by other Python scripts:

```python
from skwdconfig import cfg

cfg.get("ollama.url")        # dot-path accessor
cfg.get("paths.wallpaper")   # returns expanded path (~)
cfg.wallpaper_dir            # typed property shortcuts
cfg.ollama_url
cfg.wifi_interface
```

#### `scripts/python/build-app-cache` (453 lines)

Rebuilds `~/.cache/quickshell/app-launcher/list.jsonl`:
1. Scans desktop files + Steam games
2. Finds icons via icon theme hierarchy
3. Generates thumbnails via ImageMagick (256×256 / 460×215 Steam)
4. Applies `data/apps.json` customizations
5. Outputs JSONL: one app per line

#### `scripts/python/generate-mdi-icon-cache` (58 lines)

Extracts all glyphs from `MaterialDesignIconsDesktop.ttf` using `fontTools`. Outputs JSON with glyph names and characters for the icon picker in Config Panel.

### Bash Scripts

#### `scripts/bash/lib.sh` (121 lines)

Shared library sourced by other bash scripts:

| Function | Purpose |
|----------|---------|
| `cfg_get <path>` | Extract value from `config.json` via `jq` |
| `require_cmd <cmd>` | Exit with error if command missing |
| `has_cmd <cmd>` | Silent check, returns 0/1 |
| `apply_kde_colors <scheme>` | Apply KDE color scheme via `kwriteconfig6` |
| `detect_compositor` | Returns: `niri`, `hyprland`, `sway`, or `kwin` |
| `detect_gpu` | Returns: `nvidia`, `amd`, or `intel` |

XDG paths set: `SKWD_CONFIG`, `SKWD_CACHE`, `SKWD_RUNTIME`.

#### `scripts/bash/toggle-config-panel.sh` (19 lines)

Manages the `config_panel.py` daemon:
1. Kills any existing `config_panel.py` process via `pkill`
2. Sets up D-Bus + Wayland environment
3. Launches with `nohup` (logs to file)

Called by `custom/settings` in Waybar.

#### `scripts/bash/wm-action` (124 lines)

Compositor-agnostic window management. Auto-detects compositor via `detect_compositor()`.

| Compositor | Backend |
|-----------|---------|
| `hyprland` | `hyprctl` |
| `niri` | `niri-msg` |
| `sway` | `swaymsg` |
| `kwin` | `kdotool` / `qdbus6` |

Supported actions: `focus-window`, `close-window`, `focus-monitor`, `focus-workspace`, `list-windows`, `list-workspaces`, `list-outputs`, `event-stream`, `screenshot-window`, `screenshot-output`, `quit`.

#### `scripts/notif_watch.sh` (23 lines)

```bash
dbus-monitor "interface='org.freedesktop.Notifications'" | python3 -c "..."
```

Extracts notification data from D-Bus monitor stream, outputs JSON per notification: `{"app": "...", "summary": "...", "body": "..."}`. Piped into `NotificationToast.qml`.

---

## Configuration: `data/config.json`

Master user configuration file. Hot-reloaded by `Config.qml` on change.

### Full Structure

```json
{
  "compositor": "hyprland",
  "monitor": "DP-1",
  "terminal": "kitty",

  "paths": {
    "cache": "~/.cache/quickshell",
    "wallpaper": "~/wallpaper",
    "steam": "~/.local/share/Steam",
    "steamWorkshop": "~/.local/share/Steam/steamapps/workshop/content/431960",
    "steamWeAssets": "~/.local/share/Steam/.../wallpaper_engine/assets"
  },

  "ollama": {
    "url": "http://localhost:11434",
    "model": "gemma3:4b"
  },

  "matugen": {
    "schemeType": "scheme-fidelity",
    "kdeColorScheme": "SkwdMatugen"
  },

  "integrations": {
    "kitty":     "~/.config/kitty/skwd-theme.conf",
    "kde":       "~/.local/share/color-schemes/SkwdMatugen.colors",
    "vscode":    "~/.vscode/extensions/.../matugen-color-theme.json",
    "vesktop":   "~/.config/vesktop/themes/kitty-match.css",
    "spicetify": "~/.config/spicetify/Themes/Matugen/color.ini",
    "yazi":      "~/.config/yazi/theme.toml",
    "qt6ct":     "~/.config/qt6ct/colors/matugen.conf",
    "zen":       ""   // disabled
  },

  "intervals": {
    "weatherPollMs":         600000,  // 10 min
    "wifiPollMs":            10000,   // 10s
    "smartHomePollMs":       5000,    // 5s
    "ollamaStatusPollMs":    5000,
    "notificationExpireMs":  8000,
    "systemStatsFastSec":    3,       // CPU/RAM refresh
    "systemStatsSlowSec":    30       // disk refresh
  },

  "power": {
    "deviceType": "auto",
    "profile": "performance"
  },

  "hypridle": {
    "enabled": true,
    "warnMinutes": 9,
    "lockMinutes": 10,
    "ignoreDbusInhibit": false
  },

  "appearance": {
    "colorMode": "dark"
  },

  "wallpaperMute": true,

  "components": {
    "bar": {
      "backend": "waybar",
      "waybarConfig": "~/.config/waybar/configs/[TOP] Default",
      "waybarStyle": "~/.config/waybar/style/[Dark] Purpl.css",
      "weather": { "enabled": false, "city": "" },
      "wifi": { "enabled": false, "interface": "enp42s0" },
      "music": {
        "enabled": true,
        "preferredPlayer": "spotify",
        "visualizer": "wave",
        "visualizerTop": true,
        "visualizerBottom": true
      }
    },
    "appLauncher": true,
    "windowSwitcher": true,
    "wallpaperSelector": { "enabled": true, "showColorDots": false },
    "notifications": true,
    "lockscreen": false,
    "smartHome": false,
    "powerMenu": {
      "enabled": true,
      "items": [
        { "action": "lock",     "icon": "\uf023" },
        { "action": "logout",   "icon": "\uf2f5" },
        { "action": "reboot",   "icon": "\uf2f9" },
        { "action": "poweroff", "icon": "\uf011" }
      ]
    }
  },

  "optimization": { "enabled": false }
}
```

### Key Settings to Customize

| Setting | Effect |
|---------|--------|
| `monitor` | Primary monitor for wallpaper (e.g., `"DP-1"`, `"HDMI-A-1"`) |
| `terminal` | Terminal launched by AppLauncher for terminal apps |
| `ollama.model` | AI model used in the Asistente tab |
| `matugen.schemeType` | Color scheme type (`scheme-fidelity`, `scheme-tonal-spot`, etc.) |
| `intervals.systemStatsFastSec` | How often CPU/RAM updates in Dashboard |
| `wallpaperMute` | Mute audio when video wallpaper is active |
| `components.bar.waybarStyle` | Active Waybar CSS theme |

---

## `data/apps.json` — Per-App Customization

Overrides applied by `build-app-cache` when generating the launcher cache.

```json
{
  "Firefox": {
    "icon": "󰈹",
    "displayName": "Firefox",
    "tags": "browser web internet"
  },
  "My App": {
    "hidden": true
  },
  "Steam Game": {
    "background": "~/Pictures/custom-bg.jpg",
    "tags": "game fps"
  }
}
```

| Field | Type | Effect |
|-------|------|--------|
| `icon` | Nerd Font glyph string | Override icon in launcher |
| `displayName` | string | Override display name |
| `tags` | space-separated string | Extra search terms |
| `hidden` | bool | Remove from launcher |
| `background` | file path | Custom slice background image |

After editing `apps.json`, run `build-app-cache` to rebuild the launcher cache.

---

## Theming Pipeline (end to end)

```
1. User selects wallpaper in WallpaperPicker
        ↓
2. WallpaperApplyService applies wallpaper (swww/mpvpaper/WE)
        ↓
3. matugen image <wallpaper-path> runs
        ↓
4. Generates colors.json → ~/.cache/quickshell/colors.json
        ↓
5. Colors.qml FileView detects change → hot-reloads
        ↓
6. All QML components bound to Colors.* re-render live
        ↓
7. Matugen templates rendered → per-app theme files updated:
   - kitty skwd-theme.conf
   - qt6ct matugen.conf
   - VSCode theme JSON
   - Vesktop CSS
   - Spicetify ini/css
   - Yazi TOML
   - KDE color scheme
   ↓
8. Reload scripts called:
   - reload-kde.sh (KDE color scheme via kwriteconfig6)
   - reload-spicetify.sh
   - kitty auto-reloads via include hot-reload
```

Manual trigger:
```bash
matugen image <wallpaper-path>
# or via Hyprland script:
~/.config/hypr/scripts/DarkLight.sh
```

---

## Submodules

```bash
# Clone with submodules
git clone --recurse-submodules <repo>

# Update submodules to latest
git submodule update --remote

# Submodule paths
.config/quickshell/components/skwd-wall/  # wallpaper picker
```

The `feature/skwd/` path referenced in CLAUDE.md is the same as `components/skwd-wall/` in the current layout — the primary UI is integrated directly into `components/`.

---

## Runtime State (`state/`)

Not tracked in git. Contains:

| File | Contents |
|------|---------|
| `bar-visible` | Bar visibility state |
| `app-launcher/list.jsonl` | Built app cache |
| `app-launcher/freq.json` | Launch frequency data |

---

## Dependencies

| Tool | Required by |
|------|------------|
| `quickshell` | Everything |
| `swww` / `awww` | Static wallpaper apply |
| `mpvpaper` | Video wallpaper |
| `linux-wallpaperengine` | Steam Wallpaper Engine |
| `matugen` | Color palette generation |
| `playerctl` | Music player control |
| `wpctl` | Volume control (PipeWire) |
| `pactl` | Per-app volume |
| `grim` | Screenshots |
| `swappy` | Screenshot annotation |
| `notify-send` | Notifications |
| `hyprctl` | Window/compositor control |
| `swaync-client` | Notification center |
| `dbus-monitor` | D-Bus notification watching |
| `inotifywait` | File system watching for app installs |
| `jq` | Config parsing in bash scripts |
| `nvidia-smi` | GPU stats (NVIDIA) |
| `python3` | All Python scripts |
| `gtk4` + `libadwaita` | Config panel GUI |
| `fontTools` | MDI icon cache generator |
