#!/usr/bin/env bash
# =============================================================================
# Dotfiles Installer v3 - sadrach
# Fusion de install.sh + install2.sh
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${CYAN}${BOLD}[INFO]${NC}  $1"; }
ok()      { echo -e "${GREEN}${BOLD}[ OK ]${NC}  $1"; }
warn()    { echo -e "${YELLOW}${BOLD}[WARN]${NC}  $1"; }
error()   { echo -e "${RED}${BOLD}[ERR ]${NC}  $1"; exit 1; }
section() { echo -e "\n${BLUE}${BOLD}===  $1  =============================================${NC}"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$SCRIPT_DIR"
BACKUP_ROOT="$HOME/.dotfiles-backup"
MARKER_FILE="$HOME/.local/share/sadrach-dotfiles-installed-v3"

ASSUME_YES=false
SKIP_PACKAGES=false
MODE="auto"
WITH_ANIMATIONS="auto"      # auto|yes|no
WITH_GAMER="auto"           # auto|yes|no
WITH_PROGRAMMER="auto"      # auto|yes|no

usage() {
  cat <<'HELP'
Uso: ./install3.sh [opciones]

Opciones:
  --install          Forzar modo instalacion inicial
  --update           Forzar modo actualizacion
  --yes, -y          No pedir confirmaciones (acepta todo por defecto)
  --skip-packages    No instalar paquetes
  --animations       Activar stack visual completo
  --no-animations    Desactivar efectos visuales (Hyprland/Quickshell SI se instalan)
  --gamer            Activar modo gamer
  --no-gamer         Desactivar modo gamer
  --programmer       Activar modo programador
  --no-programmer    Desactivar modo programador
  -h, --help         Mostrar ayuda

Ejemplos:
  ./install3.sh --install --animations --gamer --programmer
  ./install3.sh --install --no-animations --no-gamer --programmer
HELP
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --install) MODE="install" ;;
    --update) MODE="update" ;;
    --yes|-y) ASSUME_YES=true ;;
    --skip-packages) SKIP_PACKAGES=true ;;
    --animations) WITH_ANIMATIONS="yes" ;;
    --no-animations) WITH_ANIMATIONS="no" ;;
    --gamer) WITH_GAMER="yes" ;;
    --no-gamer) WITH_GAMER="no" ;;
    --programmer) WITH_PROGRAMMER="yes" ;;
    --no-programmer) WITH_PROGRAMMER="no" ;;
    -h|--help) usage; exit 0 ;;
    *) error "Opcion no valida: $1" ;;
  esac
  shift
done

if [[ "$MODE" == "auto" ]]; then
  if [[ -f "$MARKER_FILE" ]]; then
    MODE="update"
  else
    MODE="install"
  fi
fi

confirm_or_exit() {
  local prompt="$1"
  if $ASSUME_YES; then
    return 0
  fi
  read -rp "$(echo -e "${YELLOW}${prompt} [s/N]: ${NC}")" ans
  [[ "$ans" =~ ^[sS]$ ]] || { echo "Cancelado."; exit 0; }
}

ask_yes_no() {
  local prompt="$1"
  local default_yes="${2:-false}"
  local ans

  if $ASSUME_YES; then
    if [[ "$default_yes" == "true" ]]; then
      return 0
    fi
    return 1
  fi

  if [[ "$default_yes" == "true" ]]; then
    read -rp "$(echo -e "${YELLOW}${prompt} [S/n]: ${NC}")" ans
    [[ -z "$ans" || "$ans" =~ ^[sS]$ ]]
  else
    read -rp "$(echo -e "${YELLOW}${prompt} [s/N]: ${NC}")" ans
    [[ "$ans" =~ ^[sS]$ ]]
  fi
}

select_optional_modules() {
  if [[ "$WITH_ANIMATIONS" == "auto" ]]; then
    if ask_yes_no "Instalar animaciones completas?" true; then
      WITH_ANIMATIONS="yes"
    else
      WITH_ANIMATIONS="no"
    fi
  fi

  if [[ "$WITH_GAMER" == "auto" ]]; then
    if ask_yes_no "Activar modo gamer (Steam/Heroic/Proton)?" false; then
      WITH_GAMER="yes"
    else
      WITH_GAMER="no"
    fi
  fi

  if [[ "$WITH_PROGRAMMER" == "auto" ]]; then
    if ask_yes_no "Activar modo programador (VS Code por yay + toolchains)?" false; then
      WITH_PROGRAMMER="yes"
    else
      WITH_PROGRAMMER="no"
    fi
  fi
}

detect_pkg_manager() {
  if command -v pacman >/dev/null 2>&1; then
    echo "pacman"
  elif command -v apt >/dev/null 2>&1; then
    echo "apt"
  elif command -v dnf >/dev/null 2>&1; then
    echo "dnf"
  else
    echo "unknown"
  fi
}

ensure_yay() {
  if command -v yay >/dev/null 2>&1; then
    ok "yay ya esta instalado"
    return 0
  fi

  section "Instalando yay"
  sudo pacman -S --needed --noconfirm git base-devel

  local tmpdir
  tmpdir="$(mktemp -d)"
  git clone https://aur.archlinux.org/yay.git "$tmpdir/yay" --depth=1
  (cd "$tmpdir/yay" && makepkg -si --noconfirm)
  rm -rf "$tmpdir"

  ok "yay instalado"
}

pacman_install() {
  local pkg
  for pkg in "$@"; do
    if pacman -Q "$pkg" >/dev/null 2>&1; then
      ok "Ya instalado (pacman): $pkg"
      continue
    fi
    if sudo pacman -S --needed --noconfirm "$pkg"; then
      ok "Instalado (pacman): $pkg"
    else
      warn "No se pudo instalar con pacman: $pkg"
    fi
  done
}

yay_install() {
  local pkg
  for pkg in "$@"; do
    if yay -Q "$pkg" >/dev/null 2>&1; then
      ok "Ya instalado (yay): $pkg"
      continue
    fi
    if yay -S --needed --noconfirm "$pkg"; then
      ok "Instalado (yay): $pkg"
    else
      warn "No se pudo instalar con yay: $pkg"
    fi
  done
}

install_quickshell() {
  if yay -Q quickshell >/dev/null 2>&1; then
    ok "Ya instalado (yay): quickshell"
    return
  fi
  if yay -Q quickshell-git >/dev/null 2>&1; then
    ok "Ya instalado (yay): quickshell-git"
    return
  fi

  if yay -S --needed --noconfirm quickshell; then
    ok "Instalado (yay): quickshell"
    return
  fi

  warn "quickshell fallo, probando quickshell-git"
  yay_install quickshell-git
}

install_base_packages_pacman() {
  section "Dependencias base del sistema"

  sudo pacman -Syu --noconfirm

  pacman_install \
    git rsync curl wget unzip zip base-devel stow tree ncdu inxi gum \
    zsh zsh-completions kitty fzf ripgrep lsd btop htop tmux neovim nano vim \
    fastfetch \
    python python-pip python-virtualenv pyenv python-pipx \
    wl-clipboard cliphist wl-clip-persist slurp grim swappy \
    rofi fuzzel wofi pavucontrol pamixer \
    blueman network-manager-applet \
    syncthing ufw \
    mpv vlc obs-studio easyeffects cava playerctl \
    thunar thunar-archive-plugin thunar-volman xarchiver unrar \
    android-file-transfer android-tools android-udev timeshift \
    brightnessctl ddcutil xdotool ydotool wtype

  pacman_install \
    ttf-jetbrains-mono ttf-jetbrains-mono-nerd \
    ttf-fira-code ttf-firacode-nerd \
    ttf-roboto ttf-roboto-mono \
    ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols-common \
    otf-font-awesome

  ensure_yay
  yay_install \
    pokemon-colorscripts-git \
    bitwarden obsidian \
    ttf-fantasque-nerd

  ok "Paquetes base listos"
}

install_core_desktop() {
  section "Core desktop (siempre)"
  pacman_install \
    hyprland hypridle hyprlock \
    hyprpolkitagent xdg-desktop-portal-hyprland

  ensure_yay
  install_quickshell

  ok "Core desktop instalado: Hyprland + Quickshell"
}

install_animation_stack() {
  section "Stack visual y animaciones"

  pacman_install \
    waybar swaync swww wlsunset \
    nwg-displays nwg-look \
    qt5ct kvantum \
    matugen wallust \
    mpvpaper

  ensure_yay
  yay_install \
    appmenu-glib-translator-git \
    aylurs-gtk-shell-git \
    libastal-meta \
    libastal-git libastal-4-git \
    libastal-apps-git libastal-auth-git libastal-battery-git \
    libastal-bluetooth-git libastal-cava-git libastal-greetd-git \
    libastal-hyprland-git libastal-io-git libastal-mpris-git \
    libastal-network-git libastal-notifd-git libastal-powerprofiles-git \
    libastal-river-git libastal-tray-git libastal-wireplumber-git \
    libastal-wl-git \
    linux-wallpaperengine-git

  ok "Stack de animaciones instalado"
}

disable_animation_features_best_effort() {
  if [[ "$WITH_ANIMATIONS" != "no" ]]; then
    return
  fi

  section "Desactivando animaciones por config (best-effort)"

  local hypr_override_dir="$HOME/.config/hypr/conf.d"
  local hypr_override_file="$hypr_override_dir/99-no-animations.conf"

  mkdir -p "$hypr_override_dir"
  cat > "$hypr_override_file" <<'EOF'
# generado por install3.sh
animations {
  enabled = false
}
decoration {
  blur {
    enabled = false
  }
  drop_shadow = false
}
EOF
  ok "Override aplicado: $hypr_override_file"
}

install_zsh_stack() {
  section "Zsh + Oh My Zsh + plugins"

  pacman_install zsh zsh-completions

  if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    info "Instalando Oh My Zsh..."
    RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    ok "Oh My Zsh instalado"
  else
    ok "Oh My Zsh ya existe"
  fi

  local zsh_custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

  if [[ ! -d "$zsh_custom/plugins/zsh-autosuggestions" ]]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions "$zsh_custom/plugins/zsh-autosuggestions" --depth=1
    ok "Plugin instalado: zsh-autosuggestions"
  else
    ok "Plugin ya existe: zsh-autosuggestions"
  fi

  if [[ ! -d "$zsh_custom/plugins/zsh-syntax-highlighting" ]]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting "$zsh_custom/plugins/zsh-syntax-highlighting" --depth=1
    ok "Plugin instalado: zsh-syntax-highlighting"
  else
    ok "Plugin ya existe: zsh-syntax-highlighting"
  fi

  ensure_yay
  yay_install pokemon-colorscripts-git

  ok "Stack de terminal listo"
}

install_gamer() {
  section "Modo gamer"

  pacman_install \
    steam steam-devices \
    gamemode lib32-gamemode \
    mangohud gamescope goverlay \
    wine-staging winetricks protontricks \
    discord gpu-screen-recorder \
    protonup-qt

  ensure_yay
  yay_install \
    heroic-games-launcher-bin \
    proton-ge-custom-bin

  # protonplus puede estar en repo o AUR segun snapshot
  if pacman -Si protonplus >/dev/null 2>&1; then
    pacman_install protonplus
  else
    yay_install protonplus
  fi

  if command -v protonup >/dev/null 2>&1; then
    info "Instalando Proton-GE latest con protonup..."
    protonup -d steam -t GE-Proton || warn "No se pudo bajar Proton-GE automaticamente, usa ProtonPlus/ProtonUp-Qt"
  else
    warn "protonup no disponible en PATH, abre ProtonPlus o ProtonUp-Qt para bajar GE latest"
  fi

  ok "Modo gamer listo"
}

install_python_stack() {
  section "Python"

  pacman_install python python-pip python-virtualenv pyenv python-pipx

  pip install --break-system-packages --upgrade \
    openai pydantic requests httpx numpy matplotlib pillow \
    pycryptodome pycryptodomex cryptography lxml pyyaml jinja2 \
    sqlparse pymysql tqdm tabulate pygments click rich setuptools wheel || \
    warn "Algunos paquetes pip no se pudieron instalar"

  ensure_yay
  yay_install \
    python-llm python-pyfzf python-click-default-group \
    python-condense-json python-sqlglot python-sqlite-fts4 \
    python-sqlite-migrate sqlite-utils mycli

  ok "Python listo"
}

install_programmer() {
  section "Modo programador"

  ensure_yay
  info "Instalando VS Code por yay (requisito)"
  yay_install visual-studio-code-bin

  pacman_install \
    git github-cli mercurial lazygit \
    docker docker-compose \
    mariadb mariadb-clients postgresql redis sqlite \
    nodejs npm node-gyp deno \
    go rustup jdk-openjdk \
    fzf ripgrep ripgrep-all jq yq \
    nmap socat \
    gcc clang cmake ninja meson make autoconf automake gdb valgrind

  ensure_yay
  yay_install \
    jetbrains-toolbox mongodb-bin mongosh-bin \
    unityhub warp-terminal ascii-image-converter

  install_python_stack

  if ! groups "$USER" | grep -q '\bdocker\b'; then
    sudo usermod -aG docker "$USER" || warn "No se pudo agregar usuario al grupo docker"
  fi
  sudo systemctl enable --now docker || warn "No se pudo habilitar docker"

  local zshrc="$HOME/.zshrc"
  if [[ -f "$zshrc" ]] && ! grep -q "# DEV ALIASES (auto)" "$zshrc"; then
    cat >> "$zshrc" <<'EOF'

# DEV ALIASES (auto)
alias dc='docker compose'
alias dps='docker ps'
alias dlogs='docker logs -f'
alias pg='psql -U postgres'
alias mg='mongosh'
alias nv='nvim'
EOF
    ok "Aliases de desarrollo agregados"
  fi

  ok "Modo programador listo"
}

backup_target() {
  local src="$1"
  local dst="$2"

  if [[ -e "$dst" || -L "$dst" ]]; then
    local ts rel backup
    ts="$(date +%Y%m%d-%H%M%S)"
    rel="${dst#${HOME}/}"
    backup="$BACKUP_ROOT/$ts/$rel"
    mkdir -p "$(dirname "$backup")"
    mv "$dst" "$backup"
    warn "Backup: $dst -> $backup"
  fi

  mkdir -p "$(dirname "$dst")"
  cp -a "$src" "$dst"
  ok "Aplicado: $dst"
}

sync_directory_contents() {
  local src_dir="$1"
  local dst_dir="$2"

  mkdir -p "$dst_dir"
  while IFS= read -r -d '' src; do
    local rel dst
    rel="${src#${src_dir}/}"
    dst="$dst_dir/$rel"

    if [[ -d "$src" ]]; then
      mkdir -p "$dst"
      continue
    fi

    if [[ -f "$dst" ]] && cmp -s "$src" "$dst"; then
      continue
    fi

    backup_target "$src" "$dst"
  done < <(find "$src_dir" -mindepth 1 -print0)
}

apply_dotfiles() {
  section "Aplicando dotfiles"
  mkdir -p "$BACKUP_ROOT"

  [[ -d "$REPO_DIR/.config" ]] || error "No existe $REPO_DIR/.config"

  info "Sincronizando .config"
  sync_directory_contents "$REPO_DIR/.config" "$HOME/.config"

  if [[ -f "$REPO_DIR/.zshrc" ]]; then
    backup_target "$REPO_DIR/.zshrc" "$HOME/.zshrc"
  fi

  if [[ -d "$REPO_DIR/wallpapers" ]]; then
    mkdir -p "$HOME/Pictures/wallpapers"
    rsync -a "$REPO_DIR/wallpapers/" "$HOME/Pictures/wallpapers/"
    ok "Wallpapers sincronizados"
  fi
}

enable_services_best_effort() {
  section "Servicios (best-effort)"

  local svc
  for svc in NetworkManager bluetooth cronie; do
    if systemctl list-unit-files | grep -q "^${svc}\\.service"; then
      sudo systemctl enable --now "$svc" || warn "No se pudo habilitar $svc"
    fi
  done

  if systemctl --user list-unit-files 2>/dev/null | grep -q "syncthing.service"; then
    systemctl --user enable --now syncthing || warn "No se pudo habilitar syncthing (user)"
  fi

  if command -v ufw >/dev/null 2>&1; then
    sudo ufw --force enable || warn "No se pudo habilitar UFW"
  fi
}

set_default_shell() {
  section "Shell por defecto"
  if command -v zsh >/dev/null 2>&1; then
    if [[ "$SHELL" != "$(command -v zsh)" ]]; then
      chsh -s "$(command -v zsh)" || warn "No se pudo cambiar shell automaticamente"
    else
      ok "zsh ya es shell por defecto"
    fi
  fi
}

install_non_arch_minimal() {
  local pkgm="$1"
  section "Instalacion minima no-Arch"

  case "$pkgm" in
    apt)
      sudo apt update
      sudo apt install -y git rsync curl wget unzip zip zsh kitty fzf ripgrep tmux neovim python3 python3-pip python3-venv
      ;;
    dnf)
      sudo dnf install -y git rsync curl wget unzip zip zsh kitty fzf ripgrep tmux neovim python3 python3-pip
      ;;
    *)
      warn "No se detecto gestor soportado. Solo se aplicaran dotfiles."
      ;;
  esac

  warn "Modo gamer/programador/animaciones avanzadas requieren Arch + yay."
}

main() {
  section "Dotfiles Installer v3"
  info "Repositorio: $REPO_DIR"
  info "Modo: $MODE"
  warn "Se crearan backups en $BACKUP_ROOT"

  confirm_or_exit "Continuar"
  select_optional_modules

  local pkgm
  pkgm="$(detect_pkg_manager)"
  info "Gestor detectado: $pkgm"
  info "Animaciones: $WITH_ANIMATIONS"
  info "Modo gamer: $WITH_GAMER"
  info "Modo programador: $WITH_PROGRAMMER"

  if [[ "$MODE" == "update" ]]; then
    section "Actualizando repo"
    if [[ -d "$REPO_DIR/.git" ]]; then
      (cd "$REPO_DIR" && git pull --ff-only) || warn "git pull no se pudo completar"
    else
      warn "No hay .git en $REPO_DIR, se omite pull"
    fi
  fi

  if ! $SKIP_PACKAGES; then
    if [[ "$pkgm" == "pacman" ]]; then
      install_base_packages_pacman
      install_core_desktop
      install_zsh_stack

      if [[ "$WITH_ANIMATIONS" == "yes" ]]; then
        install_animation_stack
      fi

      if [[ "$WITH_GAMER" == "yes" ]]; then
        install_gamer
      fi

      if [[ "$WITH_PROGRAMMER" == "yes" ]]; then
        install_programmer
      fi
    else
      install_non_arch_minimal "$pkgm"
    fi
  else
    warn "Saltando instalacion de paquetes por --skip-packages"
  fi

  apply_dotfiles
  disable_animation_features_best_effort
  enable_services_best_effort
  set_default_shell

  mkdir -p "$(dirname "$MARKER_FILE")"
  printf "mode=%s\ndate=%s\nrepo=%s\nanimations=%s\ngamer=%s\nprogrammer=%s\n" \
    "$MODE" "$(date -Iseconds)" "$REPO_DIR" "$WITH_ANIMATIONS" "$WITH_GAMER" "$WITH_PROGRAMMER" > "$MARKER_FILE"

  echo
  ok "Instalacion completada"
  info "Usa: ./install3.sh --update"
  info "Sin prompts: ./install3.sh --yes --animations --gamer --programmer"

  if [[ "$WITH_GAMER" == "yes" ]]; then
    warn "Gamer: revisa ProtonPlus/ProtonUp-Qt para confirmar Proton-GE latest"
  fi
  if [[ "$WITH_PROGRAMMER" == "yes" ]]; then
    warn "Programador: reinicia sesion para usar docker sin sudo"
  fi
}

main "$@"
