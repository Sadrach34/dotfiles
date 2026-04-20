# .zshrc Configuration

> Config path: `~/.zshrc` (symlinked from dotfiles `.zshrc`)

## Overview

Zsh configuration using Oh-My-Zsh with 4 plugins. Organized into sections: environment setup, startup display, navigation aliases, system update tooling, git workflow, and specialized utilities.

---

## Environment & PATH

PATH additions are loaded in this order (later entries take lower priority):

| Addition | Purpose |
|----------|---------|
| `~/.local/bin` | User-installed binaries |
| `~/.npm-global/bin` | Global npm packages |
| `$PYENV_ROOT/bin` | Pyenv binary |
| `~/.local/share/man` (MANPATH) | Arttime man pages |
| `~/.opencode/bin` | OpenCode CLI |

Environment variables:

| Variable | Value | Purpose |
|----------|-------|---------|
| `ZSH` | `$HOME/.oh-my-zsh` | Oh-My-Zsh install path |
| `MOZ_ENABLE_WAYLAND` | `1` | Force Firefox Wayland mode |
| `PYENV_ROOT` | `$HOME/.pyenv` | Pyenv root |
| `PYENV_REHASH_TIMEOUT` | `5` | Pyenv shim rehash timeout (seconds) |

---

## Oh-My-Zsh

```zsh
ZSH_THEME="gnzh"
```

### Plugins

| Plugin | Purpose |
|--------|---------|
| `git` | Git aliases (`gst`, `gco`, `gcmsg`, etc.) |
| `archlinux` | Arch/AUR helper aliases (`yay`, `paru` wrappers) |
| `zsh-autosuggestions` | Fish-style command suggestions from history |
| `zsh-syntax-highlighting` | Real-time syntax coloring in prompt |

---

## Startup Display

```zsh
pokemon-colorscripts --no-title -s -r | fastfetch -c ~/.config/fastfetch/config-pokemon.jsonc \
  --logo-type file-raw --logo-height 10 --logo-width 5 --logo -
```

On every new shell: random Pokémon sprite (via `pokemon-colorscripts`) is piped as the logo into `fastfetch`, which renders system info alongside it.

The plain `fastfetch` fallback is commented out at line 29.

---

## Navigation Aliases

`ls` is replaced with `lsd` for icon support:

| Alias | Command | Notes |
|-------|---------|-------|
| `ls` | `lsd` | Base replacement |
| `l` | `lsd -l` | Long list |
| `la` | `lsd -a` | Show hidden |
| `lla` | `lsd -la` | Long + hidden |
| `lt` | `lsd --tree` | Tree view |
| `rthunar` | `sudo --preserve-env=WAYLAND_DISPLAY,XDG_RUNTIME_DIR thunar` | Root file manager (preserves Wayland session) |
| `cls` | `clear` | Clear screen |
| `ff` | `clear && fastfetch` | Clear + system info |

---

## System Update Aliases

| Alias | Command | Notes |
|-------|---------|-------|
| `update` | `clear && ~/update.sh && clear && fastfetch` | Full update via update.sh, then refresh display |
| `upd` | `yay -Syu --noconfirm` | Full system + AUR, no prompts |
| `updsys` | `sudo pacman -Syu` | Official repos only |
| `updaur` | `yay -Sua` | AUR only (with prompts) |
| `updis` | `yay -S discord --noconfirm && ...` | Reinstall Discord specifically |
| `upvsc` | `yay -S visual-studio-code-bin --noconfirm && ...` | Reinstall VSCode specifically |
| `cleanup` | `yay -Sc --noconfirm && yay -Yc --noconfirm` | Clear pacman + AUR cache |
| `orphans` | `sudo pacman -Rns $(pacman -Qtdq)` | Remove orphaned packages |

---

## `Sdrx()` Function

Smart wrapper to run `install.sh` from the SdrxDots/dotfiles repo without needing to `cd` first.

### Detection Logic

```
1. Read ~/.local/share/sdrxdots-installed-v3   → parse repo= field
2. Read ~/.local/share/sadrach-dotfiles-installed-v3  → parse repo= field (legacy)
3. Check ~/SdrxDots/.git exists → use ~/SdrxDots
4. Check ~/dotfiles/.git exists → use ~/dotfiles
5. If none found → error and return 1
```

### Modes

| Argument | Mode | Behavior |
|----------|------|---------|
| `--install` or `install` | `--install` | Runs `install.sh --install` (fresh install) |
| `--update`, `update`, or empty | `--update` | Runs `install.sh --update` (sync configs) |
| `--help`, `help`, or `-h` | — | Runs `install.sh --help` |

```bash
sdrx            # update (default)
sdrx --install  # full install
sdrx --help     # show install.sh help
```

Aliased as `sdrx`.

---

## Git Aliases

| Alias | Command |
|-------|---------|
| `gits` | `git status` |
| `gitp` | `git pull` |
| `gitm` | `git commit -m "$1"` ⚠️ `$1` is literal in alias — use `gitacp` instead |
| `gitps` | `git push` |

### `gitacp()` Function

Interactive add → commit → push workflow using fzf for file selection.

```
1. Display modified files (git status --porcelain)
2. Open fzf multi-select → stage selected files (TAB to select, ENTER to confirm)
3. git commit -m "$1"  (message passed as first argument)
4. git push
   → if push fails: retry with --set-upstream origin <current-branch>
```

Color output throughout:
- Blue: file listing header
- Cyan: fzf selection prompt
- Yellow: committing
- Green: push success / completion
- Red: errors / cancellation

**Usage:**
```bash
gitacp "feat: add new module"
```

---

## Specialized Aliases & Functions

### `mc` — MySQL CLI
```bash
alias mc='mycli -u root -h 127.0.0.1'
```
Connects to local MySQL as root via `mycli`.

### `glados()` — AI Model Runner
```zsh
glados() {
    local original_dir="$PWD"
    cd ~/GlaDOS && source venv/bin/activate && python glados.py
    deactivate 2>/dev/null
    cd "$original_dir"
}
alias gl='glados'
```
Activates the `~/GlaDOS` Python venv, runs `glados.py`, then deactivates and returns to original directory. Aliased as `gl`.

### `windows` — Reboot to Windows
```bash
alias windows='sudo grub-reboot "Windows Boot Manager (en /dev/sdc1)" && reboot'
```
Sets GRUB to boot Windows Boot Manager on `/dev/sdc1` on next boot, then reboots immediately.

### `sdrxdotsctl` — Bare Repo Git
```bash
alias sdrxdotsctl='git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'
```
Manages a bare git repository at `~/.dotfiles/` with the home directory as the working tree (common bare-repo dotfiles pattern).

---

## FZF Integration

```zsh
source <(fzf --zsh)
```

Enables:
- `Ctrl+R` — fuzzy search through shell history
- `Ctrl+T` — fuzzy file picker (insert path)
- `Alt+C` — fuzzy cd into subdirectory

FZF is also used directly in `gitacp()` for file staging.

---

## History

| Setting | Value |
|---------|-------|
| `HISTFILE` | `~/.zsh_history` |
| `HISTSIZE` | `10000` |
| `SAVEHIST` | `10000` |
| `setopt appendhistory` | Append (don't overwrite) history on exit |

---

## Pyenv

Lazy initialization — only runs if `pyenv` is installed:

```zsh
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"

if command -v pyenv >/dev/null 2>&1; then
  eval "$(pyenv init - zsh)"
fi
```

This avoids startup errors when pyenv is not present. `PYENV_REHASH_TIMEOUT=5` prevents long rehash hangs.
