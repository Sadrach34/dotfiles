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
WITH_LAPTOP="auto"          # auto|yes|no

SDDM_THEME_NAME="sddm-astronaut-theme"
SDDM_THEME_VARIANT="black_hole"
SDDM_STOW_PACKAGE="sddm"

usage() {
  cat <<'HELP'
Uso: ./install.sh [opciones]

Opciones:
  --install          Forzar modo instalacion inicial
  --update           Forzar modo actualizacion
  --yes, -y          No pedir confirmaciones (acepta todo por defecto)
  --skip-packages    No instalar paquetes
  --laptop           Activar ajustes para laptop (Waybar con bateria)
  --no-laptop        Desactivar ajustes de laptop
  --animations       Activar stack visual completo
  --no-animations    Desactivar efectos visuales (Hyprland/Quickshell SI se instalan)
  --gamer            Activar modo gamer
  --no-gamer         Desactivar modo gamer
  --programmer       Activar modo programador
  --no-programmer    Desactivar modo programador
  -h, --help         Mostrar ayuda

Ejemplos:
  ./install.sh --install --animations --gamer --programmer
  ./install.sh --install --no-animations --no-gamer --programmer
HELP
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --install) MODE="install" ;;
    --update) MODE="update" ;;
    --yes|-y) ASSUME_YES=true ;;
    --skip-packages) SKIP_PACKAGES=true ;;
    --laptop) WITH_LAPTOP="yes" ;;
    --no-laptop) WITH_LAPTOP="no" ;;
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

read_marker_value() {
  local key="$1"
  awk -F= -v k="$key" '$1 == k { print $2; exit }' "$MARKER_FILE" 2>/dev/null || true
}

load_previous_option_defaults() {
  [[ "$MODE" == "update" ]] || return
  [[ -f "$MARKER_FILE" ]] || return

  local prev

  if [[ "$WITH_LAPTOP" == "auto" ]]; then
    prev="$(read_marker_value laptop)"
    [[ "$prev" =~ ^(yes|no)$ ]] && WITH_LAPTOP="$prev"
  fi

  if [[ "$WITH_ANIMATIONS" == "auto" ]]; then
    prev="$(read_marker_value animations)"
    [[ "$prev" =~ ^(yes|no)$ ]] && WITH_ANIMATIONS="$prev"
  fi

  if [[ "$WITH_GAMER" == "auto" ]]; then
    prev="$(read_marker_value gamer)"
    [[ "$prev" =~ ^(yes|no)$ ]] && WITH_GAMER="$prev"
  fi

  if [[ "$WITH_PROGRAMMER" == "auto" ]]; then
    prev="$(read_marker_value programmer)"
    [[ "$prev" =~ ^(yes|no)$ ]] && WITH_PROGRAMMER="$prev"
  fi
}

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
  if [[ "$WITH_LAPTOP" == "auto" ]]; then
    if ask_yes_no "Es laptop? (activar bateria en Waybar)" false; then
      WITH_LAPTOP="yes"
    else
      WITH_LAPTOP="no"
    fi
  fi

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
    mpv-mpris yt-dlp libnotify socat \
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
    ttf-fantasque-nerd \
    ttf-material-design-icons-desktop-git

  ok "Paquetes base listos"
}

install_core_desktop() {
  section "Core desktop (siempre)"
  pacman_install \
    hyprland hypridle hyprlock \
    hyprpolkitagent xdg-desktop-portal-hyprland \
    waybar swaync awww

  ensure_yay
  install_quickshell

  ok "Core desktop instalado: Hyprland + Quickshell"
}

install_sddm_like_sadrach() {
  section "SDDM igual que tu setup"

  pacman_install sddm qt6-svg qt6-virtualkeyboard qt6-multimedia-ffmpeg

  local stow_theme_src="$REPO_DIR/$SDDM_STOW_PACKAGE/usr/share/sddm/themes/$SDDM_THEME_NAME"
  local repo_theme_src="$REPO_DIR/$SDDM_THEME_NAME"
  local home_theme_src="$HOME/$SDDM_THEME_NAME"
  local theme_src=""
  local dst="/usr/share/sddm/themes/$SDDM_THEME_NAME"
  local src_metadata=""
  local metadata="$dst/metadata.desktop"
  local selected_variant="$SDDM_THEME_VARIANT"

  # Prefer explicit local sources that include Main.qml so we do not keep a broken system copy.
  if [[ -f "$stow_theme_src/Main.qml" ]]; then
    theme_src="$stow_theme_src"
  elif [[ -f "$repo_theme_src/Main.qml" ]]; then
    theme_src="$repo_theme_src"
  elif [[ -f "$home_theme_src/Main.qml" ]]; then
    theme_src="$home_theme_src"
  elif [[ -f "$dst/Main.qml" ]]; then
    theme_src="$dst"
  else
    error "No se encontro una copia valida de $SDDM_THEME_NAME con Main.qml"
  fi

  src_metadata="$theme_src/metadata.desktop"
  if [[ -f "$src_metadata" ]]; then
    selected_variant="$(sed -n 's|^ConfigFile=Themes/\(.*\)\.conf|\1|p' "$src_metadata" | head -n1 || true)"
    [[ -n "$selected_variant" ]] || selected_variant="$SDDM_THEME_VARIANT"
  fi

  if [[ -L "$dst" ]]; then
    warn "Se detecto symlink en $dst; se reemplazara por copia real local"
    sudo rm -f "$dst"
  fi

  sudo mkdir -p "$dst"
  if [[ "$theme_src" != "$dst" ]]; then
    sudo rsync -a --delete --exclude '.git/' "$theme_src/" "$dst/"
  else
    info "Tema ya presente en $dst, se mantiene tal cual"
  fi
  sudo chmod -R a+rX "$dst" || warn "No se pudieron normalizar permisos del tema"

  if [[ ! -f "$dst/Main.qml" ]]; then
    error "Tema incompleto en $dst: falta Main.qml"
  fi
  ok "Tema instalado: $dst"

  if [[ -d "$dst/Fonts" ]]; then
    sudo cp -a "$dst/Fonts/." /usr/share/fonts/
    if command -v fc-cache >/dev/null 2>&1; then
      sudo fc-cache -f >/dev/null 2>&1 || warn "No se pudo refrescar cache de fuentes"
    fi
  fi

  echo "[Theme]
    Current=$SDDM_THEME_NAME" | sudo tee /etc/sddm.conf >/dev/null

  sudo mkdir -p /etc/sddm.conf.d
  echo "[General]
    InputMethod=qtvirtualkeyboard" | sudo tee /etc/sddm.conf.d/virtualkbd.conf >/dev/null

  if [[ -f "$metadata" && -n "$selected_variant" ]]; then
    sudo sed -i "s|^ConfigFile=.*|ConfigFile=Themes/${selected_variant}.conf|" "$metadata"
    ok "Preset SDDM aplicado: $selected_variant"
  else
    warn "No se encontro metadata.desktop para fijar preset"
  fi

  if systemctl list-unit-files | grep -q '^sddm\.service'; then
    sudo systemctl disable display-manager.service 2>/dev/null || true
    sudo systemctl enable sddm.service || warn "No se pudo habilitar sddm.service"
  else
    warn "sddm.service no disponible aun"
  fi

  ok "SDDM configurado igual a tu setup local (Astronaut + $selected_variant)"
}

install_animation_stack() {
  section "Stack visual y animaciones"

  pacman_install \
    wlsunset \
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
# generado por install.sh
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

  if [[ -f "$REPO_DIR/update.sh" ]]; then
    backup_target "$REPO_DIR/update.sh" "$HOME/update.sh"
    chmod +x "$HOME/update.sh" || warn "No se pudo dar permisos de ejecucion a $HOME/update.sh"
  fi

  if [[ -d "$REPO_DIR/wallpapers" ]]; then
    mkdir -p "$HOME/Pictures/wallpapers"
    rsync -a "$REPO_DIR/wallpapers/" "$HOME/Pictures/wallpapers/"

    # keep legacy compatibility for tools expecting ~/wallpaper
    mkdir -p "$HOME/wallpaper"
    rsync -a "$REPO_DIR/wallpapers/" "$HOME/wallpaper/"
    ok "Wallpapers sincronizados"
  fi
}

configure_terminal_best_effort() {
  section "Terminal (kitty + zsh)"

  local kitty_conf="$HOME/.config/kitty/kitty.conf"
  if [[ -f "$kitty_conf" ]]; then
    if grep -q '^[[:space:]]*shell[[:space:]]\+' "$kitty_conf"; then
      sed -Ei 's|^[[:space:]]*shell[[:space:]]+.*$|shell /usr/bin/zsh|' "$kitty_conf"
    else
      printf '\n# fuerza zsh al abrir kitty\nshell /usr/bin/zsh\n' >> "$kitty_conf"
    fi
    ok "kitty configurado para abrir zsh"
  else
    warn "No existe $kitty_conf"
  fi
}

configure_waybar_laptop_best_effort() {
  if [[ "$WITH_LAPTOP" != "yes" ]]; then
    return
  fi

  section "Config laptop para Waybar"

  local src="$REPO_DIR/.config/waybar/config-laptop"
  local dst="$HOME/.config/waybar/config"

  if [[ ! -f "$src" ]]; then
    warn "No existe config laptop de Waybar en $src"
    return
  fi

  backup_target "$src" "$dst"
  ok "Waybar modo laptop aplicado (modulo bateria visible)"
}

configure_wallpaper_backend_best_effort() {
  section "Wallpaper backend (awww)"

  local startup_file="$HOME/.config/hypr/UserConfigs/Startup_Apps.conf"
  local wall_dir="$HOME/Pictures/wallpapers"
  local wall_current="$HOME/.config/hypr/wallpaper_effects/.wallpaper_current"
  local rofi_current="$HOME/.config/rofi/.current_wallpaper"
  local first_wall=""

  if [[ -f "$startup_file" ]]; then
    if grep -q '^[[:space:]]*exec-once[[:space:]]*=[[:space:]]*swww-daemon' "$startup_file"; then
      sed -Ei 's|^[[:space:]]*exec-once[[:space:]]*=[[:space:]]*swww-daemon[[:space:]]+--format[[:space:]]+xrgb[[:space:]]*$|exec-once = awww-daemon|' "$startup_file"
      ok "Startup_Apps.conf ajustado a awww-daemon"
    elif ! grep -q '^[[:space:]]*exec-once[[:space:]]*=[[:space:]]*awww-daemon' "$startup_file"; then
      echo 'exec-once = awww-daemon' >> "$startup_file"
      ok "Linea awww-daemon agregada a Startup_Apps.conf"
    fi
  else
    warn "No existe $startup_file, se omite ajuste de backend"
  fi

  mkdir -p "$(dirname "$wall_current")" "$(dirname "$rofi_current")"
  if [[ ! -e "$wall_current" ]]; then
    first_wall="$(find "$wall_dir" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.gif' \) | head -n1 || true)"
    if [[ -n "$first_wall" ]]; then
      ln -sf "$first_wall" "$wall_current"
      ln -sf "$first_wall" "$rofi_current"
      ok "Wallpaper inicial configurado: $first_wall"
    else
      warn "No se encontraron imagenes en $wall_dir para fijar wallpaper inicial"
    fi
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
    local zsh_bin current_shell
    zsh_bin="$(command -v zsh)"
    current_shell="$(getent passwd "$USER" | cut -d: -f7 || true)"

    if [[ "$current_shell" != "$zsh_bin" ]]; then
      if sudo usermod -s "$zsh_bin" "$USER"; then
        ok "Shell por defecto actualizado a zsh (usermod)"
      elif sudo chsh -s "$zsh_bin" "$USER"; then
        ok "Shell por defecto actualizado a zsh (chsh)"
      elif chsh -s "$zsh_bin"; then
        ok "Shell por defecto actualizado a zsh (user)"
      else
        warn "No se pudo cambiar shell automaticamente"
      fi
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
      sudo apt install -y git rsync curl wget unzip zip zsh kitty fzf ripgrep tmux neovim python3 python3-pip python3-venv cava
      ;;
    dnf)
      sudo dnf install -y git rsync curl wget unzip zip zsh kitty fzf ripgrep tmux neovim python3 python3-pip cava
      ;;
    *)
      warn "No se detecto gestor soportado. Solo se aplicaran dotfiles."
      ;;
  esac

  warn "Modo gamer/programador/animaciones avanzadas requieren Arch + yay."
}

ensure_cava_installed_best_effort() {
  section "Verificando cava"

  if command -v cava >/dev/null 2>&1; then
    ok "cava ya esta disponible"
    return
  fi

  local pkgm
  pkgm="$(detect_pkg_manager)"

  case "$pkgm" in
    pacman)
      if pacman_install cava && command -v cava >/dev/null 2>&1; then
        ok "cava instalado por pacman"
        return
      fi
      ensure_yay
      yay_install cava
      ;;
    apt)
      sudo apt update && sudo apt install -y cava || warn "No se pudo instalar cava con apt"
      ;;
    dnf)
      sudo dnf install -y cava || warn "No se pudo instalar cava con dnf"
      ;;
    *)
      warn "No hay instalador automatico de cava para este gestor"
      ;;
  esac

  if command -v cava >/dev/null 2>&1; then
    ok "cava disponible"
  else
    warn "cava sigue sin estar disponible"
  fi
}

install_custom_fonts_best_effort() {
  section "Fuentes custom (Quickshell)"

  local src_fonts="$REPO_DIR/fonts"
  local dst_fonts="$HOME/.local/share/fonts"

  if [[ ! -d "$src_fonts" ]]; then
    warn "No existe carpeta de fuentes custom en $src_fonts"
    return
  fi

  mkdir -p "$dst_fonts"
  rsync -a "$src_fonts/" "$dst_fonts/"

  # Quickshell usa varios iconos Phosphor-Bold; si no existe, se ven '?' o glifos incorrectos.
  if [[ ! -f "$dst_fonts/Phosphor-Bold.ttf" || ! -f "$dst_fonts/Phosphor.ttf" ]]; then
    info "Descargando fuentes Phosphor faltantes..."
    curl -fsSL "https://cdn.jsdelivr.net/npm/@phosphor-icons/web@2.1.1/src/bold/Phosphor-Bold.ttf" -o "$dst_fonts/Phosphor-Bold.ttf" || warn "No se pudo descargar Phosphor-Bold.ttf"
    curl -fsSL "https://cdn.jsdelivr.net/npm/@phosphor-icons/web@2.1.1/src/regular/Phosphor.ttf" -o "$dst_fonts/Phosphor.ttf" || warn "No se pudo descargar Phosphor.ttf"
  fi

  if command -v fc-cache >/dev/null 2>&1; then
    fc-cache -f "$dst_fonts" >/dev/null 2>&1 || warn "No se pudo refrescar cache de fuentes de usuario"
  fi

  ok "Fuentes custom aplicadas"
}

install_repo_update_notifier_pacman() {
  section "Notificador de nuevas versiones del repo"

  if ! command -v pacman >/dev/null 2>&1; then
    warn "pacman no detectado, se omite notificador"
    return
  fi

  local checker_tmp hook_tmp
  checker_tmp="$(mktemp)"
  hook_tmp="$(mktemp)"

  cat > "$checker_tmp" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if ! command -v git >/dev/null 2>&1; then
  exit 0
fi

if ! command -v notify-send >/dev/null 2>&1; then
  exit 0
fi

timeout_cmd=""
if command -v timeout >/dev/null 2>&1; then
  timeout_cmd="timeout 8"
fi

for marker in /home/*/.local/share/sadrach-dotfiles-installed-v3; do
  [[ -f "$marker" ]] || continue

  home_dir="${marker%/.local/share/sadrach-dotfiles-installed-v3}"
  user_name="$(basename "$home_dir")"

  repo_dir="$(awk -F= '/^repo=/{print $2; exit}' "$marker")"
  [[ -n "$repo_dir" && -d "$repo_dir/.git" ]] || continue

  local_sha="$(git -C "$repo_dir" rev-parse HEAD 2>/dev/null || true)"
  [[ -n "$local_sha" ]] || continue

  local_branch="$(git -C "$repo_dir" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  remote_sha=""

  if [[ -n "$local_branch" && "$local_branch" != "HEAD" ]]; then
    if [[ -n "$timeout_cmd" ]]; then
      remote_sha="$(timeout 8 git -C "$repo_dir" ls-remote --heads origin "refs/heads/$local_branch" 2>/dev/null | awk 'NR==1{print $1}')"
    else
      remote_sha="$(git -C "$repo_dir" ls-remote --heads origin "refs/heads/$local_branch" 2>/dev/null | awk 'NR==1{print $1}')"
    fi
  fi

  if [[ -z "$remote_sha" ]]; then
    if [[ -n "$timeout_cmd" ]]; then
      remote_sha="$(timeout 8 git -C "$repo_dir" ls-remote origin HEAD 2>/dev/null | awk 'NR==1{print $1}')"
    else
      remote_sha="$(git -C "$repo_dir" ls-remote origin HEAD 2>/dev/null | awk 'NR==1{print $1}')"
    fi
  fi

  [[ -n "$remote_sha" ]] || continue
  [[ "$local_sha" != "$remote_sha" ]] || continue

  cache_dir="$home_dir/.cache/sadrach-dotfiles"
  cache_file="$cache_dir/last_notified_remote_sha"

  mkdir -p "$cache_dir"
  chown "$user_name":"$user_name" "$cache_dir" 2>/dev/null || true

  last_notified=""
  if [[ -f "$cache_file" ]]; then
    last_notified="$(cat "$cache_file" 2>/dev/null || true)"
  fi

  if [[ "$last_notified" == "$remote_sha" ]]; then
    continue
  fi

  uid="$(id -u "$user_name" 2>/dev/null || true)"
  [[ -n "$uid" ]] || continue

  bus_path="/run/user/$uid/bus"
  if [[ ! -S "$bus_path" ]]; then
    continue
  fi

  msg="Hay una nueva version de tus dotfiles en GitHub. Ejecuta: cd $repo_dir && git pull --ff-only"

  runuser -u "$user_name" -- env DBUS_SESSION_BUS_ADDRESS="unix:path=$bus_path" \
    notify-send -a "pacman" -u normal "Dotfiles: update disponible" "$msg" || true

  printf '%s\n' "$remote_sha" > "$cache_file"
  chown "$user_name":"$user_name" "$cache_file" 2>/dev/null || true
done
EOF

  cat > "$hook_tmp" <<'EOF'
[Trigger]
Operation = Upgrade
Type = Package
Target = *

[Action]
Description = Revisando nuevas versiones de dotfiles en GitHub...
When = PostTransaction
Exec = /usr/local/bin/sadrach-dotfiles-version-check
EOF

  sudo install -Dm755 "$checker_tmp" /usr/local/bin/sadrach-dotfiles-version-check
  sudo install -Dm644 "$hook_tmp" /etc/pacman.d/hooks/99-sadrach-dotfiles-version-check.hook

  rm -f "$checker_tmp" "$hook_tmp"
  ok "Notificador instalado: pacman hook + checker"
}

main() {
  section "Dotfiles Installer v3"
  info "Repositorio: $REPO_DIR"
  info "Modo: $MODE"
  warn "Se crearan backups en $BACKUP_ROOT"

  confirm_or_exit "Continuar"
  load_previous_option_defaults
  select_optional_modules

  local pkgm
  pkgm="$(detect_pkg_manager)"
  info "Gestor detectado: $pkgm"
  info "Laptop: $WITH_LAPTOP"
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
      install_sddm_like_sadrach
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
  install_custom_fonts_best_effort
  configure_terminal_best_effort
  configure_waybar_laptop_best_effort
  configure_wallpaper_backend_best_effort
  ensure_cava_installed_best_effort
  if [[ "$pkgm" == "pacman" ]]; then
    install_repo_update_notifier_pacman
  fi
  disable_animation_features_best_effort
  enable_services_best_effort
  set_default_shell

  mkdir -p "$(dirname "$MARKER_FILE")"
  printf "mode=%s\ndate=%s\nrepo=%s\nlaptop=%s\nanimations=%s\ngamer=%s\nprogrammer=%s\n" \
    "$MODE" "$(date -Iseconds)" "$REPO_DIR" "$WITH_LAPTOP" "$WITH_ANIMATIONS" "$WITH_GAMER" "$WITH_PROGRAMMER" > "$MARKER_FILE"

  echo
  ok "Instalacion completada"
  info "Usa: ./install.sh --update"
  info "Sin prompts: ./install.sh --yes --animations --gamer --programmer"

  if [[ "$WITH_GAMER" == "yes" ]]; then
    warn "Gamer: revisa ProtonPlus/ProtonUp-Qt para confirmar Proton-GE latest"
  fi
  if [[ "$WITH_PROGRAMMER" == "yes" ]]; then
    warn "Programador: reinicia sesion para usar docker sin sudo"
  fi
}

main "$@"
