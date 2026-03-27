#!/bin/bash
# ============================================================
#   Dotfiles Installer - Sadrach
#   github.com/Sadrach34/dotfiles
# ============================================================

set -e

# ── Colores ──────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ── Helpers ───────────────────────────────────────────────────
info()    { echo -e "${CYAN}${BOLD}[INFO]${NC}  $1"; }
ok()      { echo -e "${GREEN}${BOLD}[ OK ]${NC}  $1"; }
warn()    { echo -e "${YELLOW}${BOLD}[WARN]${NC}  $1"; }
error()   { echo -e "${RED}${BOLD}[ERR ]${NC}  $1"; }
section() { echo -e "\n${BLUE}${BOLD}━━━  $1  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }

GITHUB_USER="Sadrach34"
DOTFILES_REPO="https://github.com/${GITHUB_USER}/dotfiles.git"
DOTFILES_DIR="$HOME/.dotfiles"

# ════════════════════════════════════════════════════════════
section "Bienvenido al instalador de dotfiles de Sadrach"
# ════════════════════════════════════════════════════════════
echo ""
echo -e "  Repo: ${CYAN}${DOTFILES_REPO}${NC}"
echo -e "  Este script va a:"
echo -e "   1. Instalar yay (AUR helper)"
echo -e "   2. Instalar todos los paquetes oficiales y AUR"
echo -e "   3. Clonar y aplicar tus dotfiles"
echo -e "   4. Configurar zsh como shell por defecto"
echo ""
read -rp "$(echo -e ${YELLOW}"¿Continuar? [s/N]: "${NC})" confirm
[[ "$confirm" =~ ^[sS]$ ]] || { echo "Cancelado."; exit 0; }

# ════════════════════════════════════════════════════════════
section "1. Dependencias base"
# ════════════════════════════════════════════════════════════
info "Actualizando sistema..."
sudo pacman -Syu --noconfirm

info "Instalando dependencias base..."
sudo pacman -S --needed --noconfirm \
    base-devel git curl wget zsh

# ════════════════════════════════════════════════════════════
section "2. Instalando yay (AUR helper)"
# ════════════════════════════════════════════════════════════
if command -v yay &>/dev/null; then
    ok "yay ya está instalado"
else
    info "Clonando e instalando yay..."
    cd /tmp
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
    cd ~
    ok "yay instalado"
fi

# ════════════════════════════════════════════════════════════
section "3. Paquetes oficiales"
# ════════════════════════════════════════════════════════════
OFFICIAL_PKGS=(
    adobe-source-code-pro-fonts adw-gtk-theme alsa-utils
    android-file-transfer android-tools android-udev
    audacity base base-devel bc bitwarden blender
    blueman bluez-utils brightnessctl bsd-games btop
    btrfs-progs calf cava chafa cliphist cpupower cups
    ddcutil discord dkms dolphin easyeffects efibootmgr
    espeak-ng ethtool f3 fastfetch ffmpegthumbnailer
    firefox firejail flatpak fuzzel fzf gamemode gamescope
    git github-cli gloobus-preview gnome-system-monitor
    goverlay gpu-screen-recorder grim grub
    gst-plugin-pipewire gum gvfs gvfs-mtp htop
    hypridle hyprland hyprlock hyprpolkitagent
    imagemagick inetutils intel-ucode inxi irqbalance
    iwd jdk-openjdk jq kdenlive kdiskmark kitty kvantum
    lib32-gamemode lib32-mpg123 libpulse libspng
    libva-utils linux-firmware linux-headers linux-lts
    loupe lsd mangohud mariadb matugen mercurial
    mesa-demos mesa-utils mousepad mpv mpv-mpris nano
    ncdu network-manager-applet networkmanager nmap
    noto-fonts noto-fonts-cjk noto-fonts-emoji ntfs-3g
    nvme-cli nvtop nwg-displays nwg-look obs-studio
    obsidian ollama onlyoffice-bin os-prober
    otf-font-awesome pacman-contrib pamixer pavucontrol
    piper pipewire pipewire-alsa pipewire-jack
    pipewire-pulse playerctl polkit-kde-agent postgresql
    power-profiles-daemon protonplus protontricks
    pwvucontrol pyenv python-matplotlib python-pip
    python-pipx python-pyquery python-requests
    qalculate-gtk qt5-wayland qt5ct qt6-imageformats
    qt6-tools qt6-virtualkeyboard qt6-wayland
    quickshell-git reflector rofi rustup scx-scheds
    sddm slurp smartmontools socat sof-firmware sox
    speech-dispatcher steam swappy swaync swww syncthing
    tesseract tesseract-data-eng tesseract-data-spa
    tesseract-data-chi_sim tesseract-data-chi_tra
    tesseract-data-jpn tesseract-data-kor
    tesseract-data-lat thunar thunar-archive-plugin
    thunar-volman timeshift tk tmux tree
    ttf-droid ttf-fantasque-nerd ttf-fira-code
    ttf-firacode-nerd ttf-jetbrains-mono
    ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols
    ttf-roboto ttf-roboto-mono tumbler ufw umockdev
    unrar unzip usbutils uwsm vdpauinfo vim vlc
    vulkan-radeon vulkan-tools waybar wget wine-staging
    wireless_tools wireplumber wl-clip-persist wlogout
    wlsunset wofi wtype xarchiver
    xdg-desktop-portal-hyprland xdg-user-dirs xdg-utils
    xdotool xf86-video-amdgpu xf86-video-ati xorg-server
    xorg-xinit yad yay ydotool zbar zram-generator
    zsh zsh-completions
    pokemon-colorscripts-git
)

info "Instalando paquetes oficiales (esto puede tardar varios minutos)..."
sudo pacman -S --needed --noconfirm "${OFFICIAL_PKGS[@]}" 2>/dev/null || \
    warn "Algunos paquetes no se encontraron en repos oficiales, se intentarán con yay"

# ════════════════════════════════════════════════════════════
section "4. Paquetes AUR"
# ════════════════════════════════════════════════════════════
AUR_PKGS=(
    8188eu-dkms-git
    ascii-image-converter
    aylurs-gtk-shell-git
    gradia
    gtk-engine-murrine
    jetbrains-toolbox
    mpvpaper
    mycli
    pacman4console
    piper-tts-bin
    ttf-league-gothic
    ttf-ms-fonts
    ttf-phosphor-icons
    ttf-victor-mono
    unimatrix-git
    upscayl-appimage
    visual-studio-code-bin
    wallust
    warp-terminal
    yt-dlp-git
)

info "Instalando paquetes AUR..."
yay -S --needed --noconfirm "${AUR_PKGS[@]}" || \
    warn "Algunos paquetes AUR fallaron, revisa manualmente"

# ════════════════════════════════════════════════════════════
section "5. Clonando dotfiles"
# ════════════════════════════════════════════════════════════

# Definir el alias para esta sesión
alias dotfiles="git --git-dir=${DOTFILES_DIR}/ --work-tree=${HOME}"

if [ -d "$DOTFILES_DIR" ]; then
    warn "Ya existe $DOTFILES_DIR — haciendo backup..."
    mv "$DOTFILES_DIR" "${DOTFILES_DIR}.bak.$(date +%Y%m%d%H%M%S)"
fi

info "Clonando repo bare..."
git clone --bare "$DOTFILES_REPO" "$DOTFILES_DIR"

# Backup de configs existentes antes de hacer checkout
info "Haciendo backup de configs existentes..."
BACKUP_DIR="$HOME/.dotfiles-backup-$(date +%Y%m%d%H%M%S)"
mkdir -p "$BACKUP_DIR"

git --git-dir="$DOTFILES_DIR/" --work-tree="$HOME" checkout 2>&1 \
    | grep "ya existe\|already exists\|overwrite" \
    | awk '{print $1}' \
    | while read -r file; do
        mkdir -p "$BACKUP_DIR/$(dirname "$file")"
        mv "$HOME/$file" "$BACKUP_DIR/$file" 2>/dev/null || true
    done

# Aplicar dotfiles
info "Aplicando dotfiles..."
git --git-dir="$DOTFILES_DIR/" --work-tree="$HOME" checkout
git --git-dir="$DOTFILES_DIR/" --work-tree="$HOME" config status.showUntrackedFiles no

ok "Dotfiles aplicados"
[ -d "$BACKUP_DIR" ] && [ "$(ls -A $BACKUP_DIR)" ] && \
    warn "Configs previas respaldadas en: $BACKUP_DIR"

# ════════════════════════════════════════════════════════════
section "6. Configurando el alias dotfiles en zsh"
# ════════════════════════════════════════════════════════════
ALIAS_LINE="alias dotfiles='git --git-dir=\$HOME/.dotfiles/ --work-tree=\$HOME'"

if ! grep -q "alias dotfiles" "$HOME/.zshrc" 2>/dev/null; then
    echo "" >> "$HOME/.zshrc"
    echo "# Dotfiles bare repo" >> "$HOME/.zshrc"
    echo "$ALIAS_LINE" >> "$HOME/.zshrc"
    ok "Alias agregado a .zshrc"
else
    ok "Alias ya existe en .zshrc"
fi

# ════════════════════════════════════════════════════════════
section "7. Zsh como shell por defecto"
# ════════════════════════════════════════════════════════════
if [ "$SHELL" != "$(which zsh)" ]; then
    info "Cambiando shell por defecto a zsh..."
    chsh -s "$(which zsh)"
    ok "Shell cambiado a zsh"
else
    ok "Zsh ya es tu shell por defecto"
fi

# ════════════════════════════════════════════════════════════
section "8. Servicios"
# ════════════════════════════════════════════════════════════
info "Habilitando servicios..."

sudo systemctl enable --now NetworkManager 2>/dev/null && ok "NetworkManager" || warn "NetworkManager ya activo"
sudo systemctl enable --now bluetooth 2>/dev/null && ok "Bluetooth" || warn "Bluetooth ya activo"
sudo systemctl enable sddm 2>/dev/null && ok "SDDM" || warn "SDDM ya habilitado"
sudo systemctl enable --now cups 2>/dev/null && ok "CUPS" || warn "CUPS ya activo"
sudo systemctl enable --now syncthing@$USER 2>/dev/null && ok "Syncthing" || warn "Syncthing ya activo"

# ════════════════════════════════════════════════════════════
echo ""
echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}${BOLD}║   ¡Instalación completa!                 ║${NC}"
echo -e "${GREEN}${BOLD}║                                          ║${NC}"
echo -e "${GREEN}${BOLD}║   Reinicia para aplicar todo             ║${NC}"
echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════╝${NC}"
echo ""
warn "Nota: Si usas CachyOS repo, agrégalo manualmente antes de instalar"
warn "      los paquetes cachyos-* (cachyos-keyring, cachyos-mirrorlist, etc.)"
echo ""
read -rp "$(echo -e ${YELLOW}"¿Reiniciar ahora? [s/N]: "${NC})" reboot_now
[[ "$reboot_now" =~ ^[sS]$ ]] && sudo reboot
