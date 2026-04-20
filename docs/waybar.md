# Waybar Configuration

> Config path: `.config/waybar/`

## File Index

| File | Purpose |
|------|---------|
| `config-laptop` | Main bar layout — layer, position, margins, module order |
| `Modules` | Standard waybar module definitions (409 lines) |
| `ModulesCustom` | Custom `exec`-based modules (277 lines) |
| `ModulesGroups` | Collapsible drawer groups |
| `ModulesWorkspaces` | Workspace display styles + window rewrite rules |
| `ModulesVertical` | Vertical bar module variants |
| `UserModules` | QuickShell integration modules |
| `wallust/colors-waybar.css` | Wallust-generated CSS color variables |
| `style/` | 54+ CSS theme files |

---

## Bar Layout (`config-laptop`)

```
Layer:    top
Position: top
Exclusive: true  (reserves screen space)
Spacing:  3px
Margins:  top=3  left=8  right=8
IPC:      enabled
Fixed center: true
```

### Module Order

**Left**
```
[blank] cava_mviz [blank] playerctl [blank_2] hyprland/window
```

**Center**
```
group/app_drawer [dot-line] hyprland/workspaces#rw [dot-line] qs_dashboard_top [dot-line] clock
```

**Right**
```
tray  network#speed [dot-line] group/mobo_drawer [line] group/audio [dot-line] battery  qs_dashboard
```

The config `include`s five module files at startup:
```json
"include": [
  "Modules",
  "ModulesWorkspaces",
  "ModulesCustom",
  "ModulesGroups",
  "UserModules"
]
```

---

## Standard Modules (`Modules`)

### temperature
| Property | Value |
|----------|-------|
| Interval | 10s |
| hwmon paths | `/sys/class/hwmon/hwmon1/temp1_input`, `thermal_zone0` |
| Critical threshold | 82°C |
| Icon | `󰈸` |
| Right-click | `WaybarScripts.sh --nvtop` |

### backlight
| Property | Value |
|----------|-------|
| Interval | 2s |
| Icons | 7-level brightness icons (` ` → `󰃠 `) |
| Tooltip | `backlight {percent}%` |
| Scroll up | `Brightness.sh --inc` |
| Scroll down | `Brightness.sh --dec` |

**backlight#2** — uses `intel_backlight` device, shows percentage with 2-icon set.

### battery
| Property | Value |
|----------|-------|
| States | good ≥95%, warning ≤30%, critical ≤15% |
| Format | `{icon} {capacity}%` |
| Charging | ` {capacity}%` |
| Plugged | `󱘖 {capacity}%` |
| Full | `{icon} Full` |
| Alt (click) | `{icon} {time}` — time to empty |
| Tooltip | `{timeTo} {power}w` |
| Middle-click | `ChangeBlur.sh` |
| Right-click | `Wlogout.sh` |
| Icons | 11-level battery icons `󰂎`→`󰁹` |

### bluetooth
| Property | Value |
|----------|-------|
| Idle | ` ` |
| Disabled | `󰂳` |
| Connected | `󰂱 {num_connections}` |
| Tooltip connected | Lists device aliases + battery % |
| Left-click | `blueman-manager` |

### clock (5 variants)

| Variant | Format | Notes |
|---------|--------|-------|
| `clock` | ` {:%I:%M %p}` | 12h, interval 1s, calendar tooltip |
| `clock#2` | ` {:%I:%M %p}` | Alt: full date+weekday |
| `clock#3` | `{:%I:%M %p - %d/%b}` | Compact, no tooltip |
| `clock#4` | `{:%B \| %a %d, %Y \| %I:%M %p}` | Interval 60s |
| `clock#5` | `{:%A, %I:%M %P}` | Weekday + time |

All clock variants support calendar tooltip with year view. Calendar uses colored spans for months, days, weeks, weekdays, and today.

### cpu
| Property | Value |
|----------|-------|
| Interval | 1s |
| Format | `{usage}% 󰍛` |
| Alt format | Bar graph `{icon0}{icon1}{icon2}{icon3}` + usage |
| Bar icons | `▁▂▃▄▅▆▇█` (8 levels) |
| Right-click | `gnome-system-monitor` |

### disk
| Property | Value |
|----------|-------|
| Interval | 30s |
| Path | `/` |
| Format | `{percentage_used}% 󰋊` |
| Tooltip | `{used} used out of {total} on {path} ({percentage_used}%)` |

### hyprland/language
- Keyboard: `at-translated-set-2-keyboard`
- `format-en` → `US`, `format-tr` → `Korea`
- Left-click cycles layout with `hyprctl switchxkblayout`

### hyprland/submap
- Displays active submap name in italic
- Format: `  {submap}`

### hyprland/window
| Property | Value |
|----------|-------|
| Max length | 25 chars |
| Separate outputs | true |
| Offscreen CSS text | `(inactive)` |

**Rewrite rules:**
| Pattern | Replacement |
|---------|------------|
| `(.*) — Mozilla Firefox` | ` $1` |
| `(.*) - fish` | `> [$1]` |
| `(.*) - zsh` | `> [$1]` |
| `(.*) - $term` | `> [$1]` |

### idle_inhibitor
- Activated icon: ` `, deactivated: ` `
- Tooltip reflects current state

### keyboard-state
- Tracks CapsLock: `󰪛 ` + locked/unlocked icon
- NumLock disabled (commented out)

### memory
| Property | Value |
|----------|-------|
| Interval | 10s |
| Format | `{used:0.1f}G 󰾆` |
| Alt format | `{percentage}% 󰾆` |
| Tooltip | `{used:0.1f}GB/{total:0.1f}G` |
| Right-click | `WaybarScripts.sh --btop` |

### mpris
| Property | Value |
|----------|-------|
| Interval | 10s |
| Format playing | `{player_icon} ` |
| Format paused | `{status_icon} {dynamic}` (italic) |
| Left-click | `playerctl previous` |
| Middle-click | `playerctl play-pause` |
| Right-click | `playerctl next` |
| Scroll | Volume via `Volume.sh` |
| Max length | 30 chars |

Player icons: chromium ``, firefox ``, mpv `󰐹`, spotify ``, vlc `󰕼`, default ``

### network
| Property | Value |
|----------|-------|
| WiFi icons | 5-level signal `󰤯`→`󰤨` |
| Ethernet | `󰌘` |
| Disconnected | `󰌙` |
| Tooltip | IP, upload/download bandwidth |
| Right-click | `WaybarScripts.sh --nmtui` |

**network#speed** — same as above but shows live `{bandwidthUpBytes}` and `{bandwidthDownBytes}`, min/max length locked at 24 chars, interval 1s.

### power-profiles-daemon
| Property | Value |
|----------|-------|
| Tooltip | Profile name + driver |
| Left-click | Cycles: power-saver → balanced → performance → power-saver |
| Icons | default ``, performance ``, balanced ``, power-saver `` |

### pulseaudio
| Variant | Notes |
|---------|-------|
| `pulseaudio` | `{icon} {volume}%`, Bluetooth indicator `󰂰`, muted `󰖁`. Left-click toggle, right-click pavucontrol tab 1, scroll volume |
| `pulseaudio#1` | Muted icon `󰸈`, right-click pavucontrol tab 3 |
| `pulseaudio#microphone` | `{format_source}`, ` {volume}%`, muted ``. Left-click mic toggle, right-click pavucontrol tab 4 |

Scroll step: 5% for all variants.

### tray
- Icon size: 20px, spacing: 4px

### wireplumber
- Format: `{icon} {volume} %`, muted: ` Mute`
- Same click/scroll actions as pulseaudio
- Icons: ``, ``, `󰕾`, ``

### wlr/taskbar
- Format: `{icon} {name}`, icon size 16px
- Middle-click closes window
- Ignores: `wofi`, `rofi`, `kitty`, `kitty-dropterm`

---

## Custom Modules (`ModulesCustom`)

### custom/weather
| Property | Value |
|----------|-------|
| Interval | 3600s (1 hour) |
| Exec | `~/.config/hypr/UserScripts/Weather.py` |
| Return type | JSON (supports tooltip) |

### custom/hyprpicker
- Format: ``
- Left-click: `hyprpicker | wl-copy` (copies hex color to clipboard)

### custom/file_manager
- Format: ` `
- Left-click: `WaybarScripts.sh --files`

### custom/tty
- Format: ` `
- Left-click: `WaybarScripts.sh --term`

### custom/browser
- Format: ` `
- Left-click: `xdg-open https://`

### custom/settings
- Format: ` `
- Left-click: `toggle-config-panel.sh` (QuickShell config panel)

### custom/cycle_wall
| Click | Action |
|-------|--------|
| Left | `WallpaperSelect.sh` — wallpaper picker menu |
| Middle | `WaybarStyles.sh` — Waybar style picker |
| Right | `WallpaperRandom.sh` — random wallpaper |

### custom/hint
| Click | Action |
|-------|--------|
| Left | `KeyHints.sh` — quick tips |
| Right | `KeyBinds.sh` — full keybinds |

### custom/dot_update
- Format: ` 󰁈 `
- Left-click: `sadrach34DotsUpdate.sh`

### custom/hypridle
| Property | Value |
|----------|-------|
| Interval | 60s |
| Exec | `Hypridle.sh status` (JSON return) |
| Left-click | `Hypridle.sh toggle` |
| Right-click | `hyprlock` |

### custom/keyboard
- Reads `~/.cache/kb_layout` every 1s
- Format: ` {layout}`
- Left-click: `SwitchKeyboardLayout.sh`

### custom/light_dark
| Click | Action |
|-------|--------|
| Left | `DarkLight.sh` — full theme switch |
| Middle | `WallpaperSelect.sh` |
| Right | `WaybarStyles.sh` |

### custom/lock
- Format: `󰌾`
- Left-click: `LockScreen.sh`

### custom/menu
| Click | Action |
|-------|--------|
| Left | `rofi -show drun` — app launcher |
| Middle | `WallpaperSelect.sh` |
| Right | `WaybarLayout.sh` — layout picker |

### custom/cava_mviz
- Exec: `WaybarCava.sh`
- Real-time audio visualization in bar

### custom/playerctl
| Property | Value |
|----------|-------|
| Max length | 25 chars |
| Format | `{artist}  {title}` (JSON) |
| Tooltip | `{playerName} : {title}` |
| Left-click | `playerctl previous` |
| Middle-click | `playerctl play-pause` |
| Right-click | `playerctl next` |
| Scroll | Volume via `Volume.sh` |

### custom/power
| Click | Action |
|-------|--------|
| Left | `Wlogout.sh` — logout menu |
| Right | `ChangeBlur.sh` — blur settings |

### custom/reboot
- Format: `󰜉`
- Left-click: `systemctl reboot`

### custom/quit
- Format: `󰗼`
- Left-click: `hyprctl dispatch exit`

### custom/swaync
| Click | Action |
|-------|--------|
| Left | `swaync-client -t -sw` — toggle notification center |
| Right | `swaync-client -d -sw` — toggle Do Not Disturb |

Icons reflect notification state + DND state:
- Active notification: red dot superscript ``
- DND variants: `` (bell off)
- Inhibited variants also tracked

### custom/updater
| Property | Value |
|----------|-------|
| Interval | 43200s (12 hours) |
| Exec | `checkupdates \| wc -l` |
| Format | ` {count}` |
| Left-click | `Distro_update.sh` |
| Requires | `pacman-contrib` |

### Separators

| Module | Display |
|--------|---------|
| `separator#dot` | `` |
| `separator#dot-line` | `` |
| `separator#line` | `\|` |
| `separator#blank` | `` (empty) |
| `separator#blank_2` | `  ` (2 spaces) |
| `separator#blank_3` | `   ` (3 spaces) |
| `arrow1`–`arrow10` | Powerline arrow glyphs |

All separators use `"interval": "once"` — no polling.

---

## Module Groups (`ModulesGroups`)

All groups use drawer animation with 500ms transition unless noted.

| Group | Trigger module | Direction | Members |
|-------|---------------|-----------|---------|
| `group/app_drawer` | `custom/menu` | left→right | menu, file_manager, tty, browser, settings |
| `group/motherboard` | — (no drawer) | horizontal | cpu, power-profiles-daemon, memory, temperature, disk |
| `group/mobo_drawer` | `cpu` | left→right | temperature, cpu, power-profiles-daemon, memory, disk |
| `group/laptop` | — (no drawer) | inherit | backlight, battery |
| `group/audio` | `pulseaudio` | left→right | pulseaudio, pulseaudio#microphone |
| `group/connections` | `bluetooth` | left→right | network, bluetooth |
| `group/status` | `custom/power` | right←left | power, lock, keyboard-state, keyboard |
| `group/notify` | `custom/swaync` | right←left | swaync, dot_update |
| `group/power` | (drawer-child) | right←left | power, quit, lock, reboot |
| `group/power#vert` | (not-memory) | right←left, 300ms | power, lock, logout, reboot |

The first module listed is always the visible "handle" — the rest expand on hover/click.

---

## Workspace Styles (`ModulesWorkspaces`)

All styles use `persistent-workspaces: {"*": 5}` — always show 5 workspaces per output.
Scroll up/down navigates workspaces via `hyprctl dispatch workspace e±1`.

| Style key | Display | Notes |
|-----------|---------|-------|
| `hyprland/workspaces` | `` active / `` default | Circles |
| `#roman` | I II III IV V … X | Roman numerals |
| `#pacman` | `󰮯` active / `` empty / `󰊠` default | Pacman characters |
| `#kanji` | 一 二 三 四 五 … 十 | Japanese, scroll disabled |
| `#cam` | Uno Due Tre Quattro Cinque … Dieci | Italian |
| `#4` | `{name} {icon}` | Number + app icon per workspace |
| `#numbers` | 1 2 3 4 5 … 10 | Plain numerals |
| `#rw` | `{icon} {windows}` | Number + active window icons |

**Active config:** `hyprland/workspaces#rw` is used in `config-laptop`.

### Window Rewrite Rules (used in `#rw`)

| Category | Apps | Icon |
|----------|------|------|
| Browsers | Firefox, LibreWolf, Floorp, Cachy-browser | ` ` |
| | Zen | `󰰷 ` |
| | Waterfox | ` ` |
| | Edge | ` ` |
| | Chromium, Chrome, Thorium | ` ` |
| | Brave | `🦁 ` |
| | Tor Browser | ` ` |
| | Firefox Dev Edition | `🦊 ` |
| Terminals | kitty, konsole | ` ` |
| | kitty-dropterm | ` ` |
| | Ghostty | ` ` |
| | WezTerm | ` ` |
| Email | Thunderbird, Betterbird | ` ` |
| | Gmail (title) | `󰊫 ` |
| Messaging | Telegram | ` ` |
| | Discord, Webcord, Vesktop | ` ` |
| | WhatsApp/ZapZap (title) | ` ` |
| | Messenger (title) | ` ` |
| | Facebook (title) | ` ` |
| AI | ChatGPT, DeepSeek, Qwen (title) | `󰚩 ` |
| | Slack | ` ` |
| Media | mpv | ` ` |
| | Celluloid, Zoom | ` ` |
| | Cider | `󰎆 ` |
| | YouTube (title) | ` ` |
| | VLC | `󰕼 ` |
| | cmus (title) | ` ` |
| | Spotify | ` ` |
| | Plex | `󰚺 ` |
| | Picture-in-Picture | ` ` |
| Virtualization | virt-manager | ` ` |
| | VirtualBox | `💽 ` |
| | Remmina | `🖥️ ` |
| Dev | VSCode, VSCodium, code-oss | `󰨞 ` |
| | Zed | `󰵁` |
| | CodeBlocks | `󰅩 ` |
| | GitHub (title) | ` ` |
| | Mousepad | ` ` |
| | LibreOffice Writer | ` ` |
| | LibreOffice Calc | ` ` |
| | LibreOffice Start | `󰏆 ` |
| | Neovim/Vim (title) | ` ` |
| | Figma (title) | ` ` |
| | Jira (title) | ` ` |
| | JetBrains IDEA | ` ` |
| | Sublime Text | `󰅳 ` |
| Tools | OBS | ` ` |
| | Polkit agent | `󰒃 ` |
| | nwg-look | ` ` |
| | PavuControl | `󱡫 ` |
| | Steam | ` ` |
| | Thunar/Nemo | `󰝰 ` |
| | GParted | `` |
| | GIMP | ` ` |
| | Android Emulator | `📱 ` |
| | Android Studio | ` ` |
| | Helvum (audio routing) | `󰓃` |
| | LocalSend | `` |
| | 3D slicers (Prusa/Cura/Orca) | `󰹛` |
| Misc | Amazon (title) | ` ` |
| | Reddit (title) | ` ` |

Default (unmatched): ` `

---

## Vertical Modules (`ModulesVertical`)

These override standard modules for vertical bar layouts:

| Module | Key difference |
|--------|---------------|
| `temperature#vertical` | Critical at 80°C (not 82) |
| `backlight#vertical` | `rotate: 1` (90°), 15-level icons |
| `clock#vertical` | Format stacks H/M/S/date vertically, interval 1s |
| `cpu#vertical` | Icon above percentage |
| `memory#vertical` | Icon above value |
| `pulseaudio#vertical` | Mute indicators, tooltip with description |
| `pulseaudio#microphone#vertical` | Same as standard mic variant |
| `custom/power#vertical` | Triggers `Wlogout.sh` |

---

## User Modules (`UserModules`)

Two QuickShell integration modules:

### custom/qs_dashboard
- Format: `☰`
- Toggles the main QuickShell dashboard
- If QuickShell not running: starts it, waits 600ms, then calls IPC toggle
```bash
if pgrep -x quickshell >/dev/null; then
  qs ipc call dashboard toggle
else
  quickshell >/dev/null 2>&1 & sleep 0.6
  qs ipc call dashboard toggle
fi
```

### custom/qs_dashboard_top
- Same logic but calls `qs ipc call toppanel toggle`
- Used in center bar to toggle the QuickShell top panel

---

## Theming

### Wallust Colors (`wallust/colors-waybar.css`)

Auto-generated by matugen/wallust from the current wallpaper. Do not edit manually.

| Variable | Value | Role |
|----------|-------|------|
| `@foreground` | `#EAD2CD` | Text |
| `@background` | `#272227` | Bar background |
| `@background-alt` | `rgba(39,34,39,0.25)` | Translucent surfaces |
| `@cursor` | `#AD8CB1` | Cursor/accent |
| `@color0`–`@color15` | Various | Full ANSI palette |

### Style Files (`style/`)

54+ CSS themes organized by category:

| Category | Examples |
|----------|---------|
| Catppuccin | Mocha, Frappe, Latte, RGB variants |
| Wallust | Box, Colored, Chroma, Edge, Simple |
| Colorful | Aurora, Aurora Blossom, Rainbow Spectrum, Oglo Chicklets |
| Dark | Golden Eclipse, Half-Moon, Obsidian Edge, Purpl |
| Light | Latte, Monochrome Contrast, Obsidian Glow |
| Special | Transparent Crystal Clear, Neon Circuit, Rose Pine, EverForest |
| Vertical | Vertical bar layout variants |

Switch styles via `WaybarStyles.sh` (accessible from `custom/cycle_wall` middle-click or `custom/light_dark` right-click).

---

## Scripts Referenced

All scripts live under `.config/hypr/scripts/` or `.config/hypr/UserScripts/`:

| Script | Called by |
|--------|-----------|
| `WaybarScripts.sh --nvtop` | temperature right-click |
| `Brightness.sh --inc/--dec` | backlight scroll |
| `ChangeBlur.sh` | battery middle-click, power right-click |
| `Wlogout.sh` | battery right-click, power left-click |
| `Volume.sh --inc/--dec/--toggle/--toggle-mic/--mic-inc/--mic-dec` | pulseaudio, mpris, playerctl scroll/click |
| `WaybarScripts.sh --btop` | memory right-click |
| `WaybarScripts.sh --nmtui` | network right-click |
| `WaybarScripts.sh --files` | file_manager click |
| `WaybarScripts.sh --term` | tty click |
| `UserScripts/Weather.py` | weather exec |
| `UserScripts/WallpaperSelect.sh` | cycle_wall left, menu middle, light_dark middle |
| `UserScripts/WallpaperRandom.sh` | cycle_wall right |
| `WaybarStyles.sh` | cycle_wall middle, light_dark right |
| `WaybarLayout.sh` | menu right-click |
| `DarkLight.sh` | light_dark left-click |
| `LockScreen.sh` | lock left-click |
| `KeyHints.sh` | hint left-click |
| `KeyBinds.sh` | hint right-click |
| `Hypridle.sh status/toggle` | hypridle exec/click |
| `SwitchKeyboardLayout.sh` | keyboard click |
| `sadrach34DotsUpdate.sh` | dot_update click |
| `Distro_update.sh` | updater click |
| `toggle-config-panel.sh` | settings click (quickshell script) |
