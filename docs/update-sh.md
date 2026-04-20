# update.sh

> Script path: `~/update.sh` (symlinked from dotfiles `update.sh`)

## Overview

Comprehensive Arch/CachyOS system update and maintenance script. Runs 5 sequential steps covering package sync, official package update, AUR update, cache cleanup, and orphan removal. Designed to continue through partial failures and report warnings at the end.

Optimized for **CachyOS** (custom kernel, CachyOS-specific keyring) but compatible with any Arch-based distro.

---

## Usage

```bash
~/update.sh          # run directly
update               # via .zshrc alias (clear → update → clear → fastfetch)
```

The `update` alias in `.zshrc` wraps the script:
```bash
alias update='clear && ~/update.sh && clear && fastfetch'
```

---

## Color System

All output uses ANSI escape codes:

| Variable | Code | Usage |
|----------|------|-------|
| `GREEN` | `\e[32m` | Success messages (`✓`) |
| `BLUE` | `\e[34m` | Step headers, informational |
| `YELLOW` | `\e[33m` | Warnings, recommendations (`⚠`) |
| `RED` | `\e[31m` | Critical errors (`✗`) |
| `CYAN` | `\e[36m` | Banner borders, final status line |
| `RESET` | `\e[0m` | Reset after colored output |

---

## Helper Functions

### `show_banner()`

Displays a cyan-bordered header at script start:

```
╔═══════════════════════════════════════════════╗
║       ACTUALIZACIÓN DEL SISTEMA - ARCH        ║
╚═══════════════════════════════════════════════╝
```

### `find_sdrxdots_repo_dir()`

Locates the SdrxDots/dotfiles repository. Used by `notify_sdrxdots_update_if_available()`.

Detection sequence (first match wins):

```
1. ~/.local/share/sdrxdots-installed-v3    → read repo= field with awk
2. ~/.local/share/sadrach-dotfiles-installed-v3  → read repo= field (legacy marker)
3. ~/SdrxDots/.git exists                  → return ~/SdrxDots
4. ~/dotfiles/.git exists                  → return ~/dotfiles
5. Nothing found                           → return empty string (caller handles)
```

Only returns the path if a `.git` directory is confirmed inside it.

### `notify_sdrxdots_update_if_available()`

Checks GitHub for available SdrxDots updates before updating packages. Silently skips if git is unavailable or repo not found.

```
1. find_sdrxdots_repo_dir() → get local repo path
2. git rev-parse HEAD       → get local commit SHA
3. git rev-parse --abbrev-ref HEAD  → get current branch name
4. git ls-remote origin refs/heads/<branch>  → get remote SHA
   → fallback: git ls-remote origin HEAD
5. Compare local_sha vs remote_sha
   → if different: print yellow warning + send desktop notification
```

Desktop notification via `notify-send`:
```
App:     update.sh
Urgency: normal
Title:   SdrxDots: update disponible
Body:    cd <repo_dir> && git pull --ff-only
```

### `sync_databases()`

Syncs pacman package databases with automatic keyring repair on signature errors.

```
1. sudo pacman -Sy  (output tee'd to temp file)
   → success: return 0

2. If output contains "firma" or "signature" (case-insensitive):
   a. sudo pacman-key --populate archlinux
   b. sudo pacman-key --refresh-keys
   c. Install/upgrade: archlinux-keyring, cachyos-keyring (or archlinux-keyring alone)
   d. sudo pacman -Syy  (force double-sync)
      → success: return 0

3. If still failing: return 1
```

Temp log file is always cleaned up (`rm -f`).

---

## Execution Steps

### [1/4] Database Sync

```bash
notify_sdrxdots_update_if_available   # check GitHub for dotfiles updates
sync_databases                         # sync package DBs (with keyring auto-repair)
```

- On failure: prints error + keyring advice, **exits immediately** (`exit 1`)
- This is the only step that can abort the entire script

### [2/4] Official Package Update

```bash
sudo pacman -Su --noconfirm
```

- Installs pending updates from synced databases
- `-Su` (not `-Syu`) because `-Sy` already ran in step 1
- On failure: sets `WARNINGS=1`, continues

### [3/4] AUR Package Update

```bash
yay -Sua --noconfirm
```

- `-Sua` — update AUR packages only (skips official repo packages)
- On failure: sets `WARNINGS=1`, continues

### [4/4] Cache Cleanup

Three sub-steps:

**a) Incomplete download cleanup**
```bash
sudo find /var/cache/pacman/pkg/ -maxdepth 1 -type d -name "download-*"
```
Removes any `download-*` temp directories left by interrupted downloads.

**b) Package cache cleanup**
```bash
paccache -r              # keep last 3 versions of each package
# fallback if paccache unavailable:
sudo pacman -Sc --noconfirm
```
`paccache` is from the `pacman-contrib` package. If missing, falls back to `pacman -Sc` (keeps only currently installed versions — more aggressive).

**c) AUR cache cleanup**
```bash
yay -Sc --aur --noconfirm
```
Cleans yay's AUR build cache.

### [5/5] Orphan Package Cleanup

```bash
orphans=$(pacman -Qtdq 2>/dev/null)
```

If any orphans found: lists them in yellow, then:
```bash
sudo pacman -Rns --noconfirm $orphans
```

`-Rns` removes the packages, their unneeded dependencies, and their configuration files.

On failure: sets `WARNINGS=1`, continues (does not abort).

---

## Error Handling Strategy

| Mechanism | Behavior |
|-----------|---------|
| `WARNINGS=0` counter | Incremented on non-fatal failures |
| Step 1 exit on failure | Only DB sync aborts — all other steps are non-fatal |
| `|| true` pattern | Prevents keyring sub-commands from stopping the script |
| Temp file cleanup | `mktemp` log always deleted even on error |
| Fallback commands | `paccache` → `pacman -Sc` on missing tool |

---

## Post-Update Checks

After cleanup, the script checks if critical components were updated:

```bash
pacman -Qu 2>/dev/null | grep -qE "linux|systemd"
```

If `linux` kernel or `systemd` was updated:
```
⚠ IMPORTANTE: Se actualizaron componentes críticos.
  Es recomendable reiniciar el sistema.
```

---

## Final Output

```
═══════════════════════════════════════════════
✓ ¡Sistema actualizado correctamente!      ← if WARNINGS=0
⚠ Sistema actualizado con advertencias.    ← if WARNINGS>0
═══════════════════════════════════════════════
```

Script ends with:
```bash
read -p "Presiona Enter para salir..."
```

This pause allows the user to read the full output before the terminal clears (since the `update` alias runs `clear && fastfetch` after the script exits).

---

## Exit Codes

| Code | Condition |
|------|-----------|
| `0` | Script completed (with or without warnings) |
| `1` | DB sync failed — cannot continue safely |
