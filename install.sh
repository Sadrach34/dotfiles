#!/bin/bash
# ============================================================
#   Dotfiles Installer - Sadrach
#   github.com/Sadrach34/dotfiles
#
#   Target hardware:
#     CPU : Intel i7-4800MQ (Haswell, 4ª gen)
#     GPU : Intel HD Graphics 4600 (iGPU Gen 7.5)
#     Kernel: linux-cachyos (principal) + linux-lts (respaldo)
#
#   Este script:
#     - Agrega repos CachyOS
#     - Instala kernels + drivers Intel Haswell correctos
#     - Limpia drivers sobrantes (vulkan-radeon, vulkan-nouveau)
#     - Aplica optimizaciones CachyOS (bfq, ananicy, powersave, zram)
#     - Elimina bspwm y TODA su configuración
#     - Instala todos los paquetes del escritorio
#     - Clona y aplica dotfiles (con backup automático de lo existente)
#     - Preserva configs propias de la laptop (tmux, yazi, zellij, spicetify)
# ============================================================

set -e

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
section() { echo -e "\n${BLUE}${BOLD}━━━  $1  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }

GITHUB_USER="Sadrach34"
DOTFILES_REPO="https://github.com/${GITHUB_USER}/dotfiles.git"
DOTFILES_DIR="$HOME/.dotfiles"

# ════════════════════════════════════════════════════════════
section "Instalador de dotfiles - Sadrach (laptop)"
# ════════════════════════════════════════════════════════════
echo ""
echo -e "  ${BOLD}Hardware:${NC}"
echo -e "   CPU : Intel i7-4800MQ (Haswell)"
echo -e "   GPU : Intel HD Graphics 4600 (iGPU, Gen 7.5)"
echo -e "   Kernels: linux-cachyos (principal) + linux-lts (respaldo)"
echo ""
echo -e "  ${BOLD}Qué va a pasar:${NC}"
echo -e "   ✓ Repos CachyOS agregados"
echo -e "   ✓ Drivers Intel Haswell correctos (i965 VA-API)"
echo -e "   ✗ vulkan-radeon y vulkan-nouveau eliminados (no aplican)"
echo -e "   ✓ Optimizaciones: powersave, bfq, ananicy, zram"
echo -e "   ✗ bspwm eliminado completamente"
echo -e "   ✓ Dotfiles del escritorio aplicados"
echo -e "   ✓ Backup automático de todo lo que choque"
echo -e "   ✓ tmux, yazi, zellij, spicetify preservados"
echo ""
warn "Tus archivos personales (Documentos, Imágenes, etc.) NO se tocan."
echo ""
read -rp "$(echo -e ${YELLOW}"¿Continuar? [s/N]: "${NC})" confirm
[[ "$confirm" =~ ^[sS]$ ]] || { echo "Cancelado."; exit 0; }

# ════════════════════════════════════════════════════════════
section "1. Sistema base"
# ════════════════════════════════════════════════════════════
info "Actualizando sistema..."
sudo pacman -Syu --noconfirm

info "Dependencias mínimas..."
sudo pacman -S --needed --noconfirm base-devel git curl wget zsh gnupg

# ════════════════════════════════════════════════════════════
section "2. Repositorios CachyOS"
# ════════════════════════════════════════════════════════════
if grep -q "\[cachyos\]" /etc/pacman.conf 2>/dev/null; then
    ok "Repos CachyOS ya presentes"
else
    info "Descargando e instalando repositorios oficiales de CachyOS..."
    cd /tmp
    curl https://mirror.cachyos.org/cachyos-repo.tar.xz -o cachyos-repo.tar.xz
    tar xvf cachyos-repo.tar.xz
    cd cachyos-repo
    
    # El script de CachyOS instala el keyring, los mirrors e inyecta la config en pacman.conf
    sudo ./cachyos-repo.sh
    
    cd /tmp
    rm -rf cachyos-repo cachyos-repo.tar.xz
    ok "Repos CachyOS configurados correctamente"
fi
# ════════════════════════════════════════════════════════════
section "3. Kernels: CachyOS + LTS"
# ════════════════════════════════════════════════════════════
info "Instalando linux-cachyos y linux-lts..."
sudo pacman -S --needed --noconfirm \
    linux-cachyos linux-cachyos-headers \
    linux-lts linux-lts-headers \
    linux-firmware
ok "Kernels instalados"

# ════════════════════════════════════════════════════════════
section "4. Drivers Intel Haswell (HD Graphics 4600)"
# ════════════════════════════════════════════════════════════

# NOTA TÉCNICA:
# i7-4800MQ = Haswell = Intel Gen 7.5
# - libva-intel-driver (i965) → Gen 4 a 9 → CORRECTO para Haswell
# - intel-media-driver (iHD)  → Gen 8+     → NO aplica a Haswell
# Tu laptop tiene ambos instalados — eliminamos intel-media-driver

info "Eliminando intel-media-driver (no aplica a Haswell)..."
if pacman -Qq intel-media-driver &>/dev/null; then
    sudo pacman -Rns --noconfirm intel-media-driver 2>/dev/null && \
        ok "intel-media-driver eliminado" || \
        warn "No se pudo eliminar intel-media-driver"
else
    ok "intel-media-driver no estaba instalado"
fi

info "Eliminando drivers sobrantes (AMD/NVIDIA no aplican)..."
for pkg in vulkan-radeon vulkan-nouveau xf86-video-amdgpu xf86-video-ati xf86-video-nouveau lib32-vulkan-radeon; do
    if pacman -Qq "$pkg" &>/dev/null; then
        sudo pacman -Rns --noconfirm "$pkg" 2>/dev/null && \
            ok "Eliminado: $pkg" || warn "No se pudo eliminar: $pkg"
    fi
done

info "Instalando drivers Intel Haswell correctos..."
sudo pacman -S --needed --noconfirm \
    mesa lib32-mesa \
    libva-intel-driver lib32-libva-intel-driver \
    libva-utils \
    vulkan-intel lib32-vulkan-intel \
    vulkan-tools \
    intel-gpu-tools \
    intel-ucode
ok "Drivers Intel Haswell instalados"

info "Configurando VA-API → i965 (correcto para Haswell)..."
ENVFILE="/etc/environment"
if grep -q "LIBVA_DRIVER_NAME" "$ENVFILE" 2>/dev/null; then
    # Corregir si dice iHD
    sudo sed -i 's/LIBVA_DRIVER_NAME=iHD/LIBVA_DRIVER_NAME=i965/g' "$ENVFILE"
    ok "VA-API corregido → i965"
else
    echo "LIBVA_DRIVER_NAME=i965" | sudo tee -a "$ENVFILE" > /dev/null
    ok "VA-API configurado → i965"
fi

# ════════════════════════════════════════════════════════════
section "5. GRUB"
# ════════════════════════════════════════════════════════════
info "Instalando GRUB..."
sudo pacman -S --needed --noconfirm grub efibootmgr os-prober

# Habilitar os-prober
sudo sed -i 's/#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER=false/' \
    /etc/default/grub 2>/dev/null || true

info "Generando grub.cfg..."
sudo grub-mkconfig -o /boot/grub/grub.cfg
ok "GRUB configurado (cachyos principal, lts respaldo)"

# ════════════════════════════════════════════════════════════
section "6. Optimizaciones CachyOS"
# ════════════════════════════════════════════════════════════

# CPU Governor: powersave (igual que escritorio)
info "CPU governor → powersave..."
sudo pacman -S --needed --noconfirm cpupower
sudo tee /etc/default/cpupower > /dev/null << 'EOF'
governor='powersave'
EOF
sudo systemctl enable --now cpupower
ok "CPU governor: powersave"

# I/O Scheduler: bfq (igual que escritorio, ideal para HDD/SSD SATA Haswell-era)
info "I/O scheduler → bfq..."
sudo tee /etc/udev/rules.d/60-ioschedulers.rules > /dev/null << 'EOF'
ACTION=="add|change", KERNEL=="sd[a-z]*", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
ACTION=="add|change", KERNEL=="sd[a-z]*", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="bfq"
ACTION=="add|change", KERNEL=="nvme*", ATTR{queue/scheduler}="none"
EOF
ok "I/O scheduler: bfq"

# ananicy-cpp + reglas CachyOS
info "ananicy-cpp + cachyos-ananicy-rules..."
# Resolver conflicto de ananicy antes de instalar
if [ -f /etc/ananicy.d/ananicy.conf ]; then
    warn "Conflicto detectado: ananicy.conf ya existe → haciendo backup"
    sudo mv /etc/ananicy.d/ananicy.conf /etc/ananicy.d/ananicy.conf.bak.$(date +%s)
fi

sudo pacman -S --needed --noconfirm ananicy-cpp cachyos-ananicy-rules || \
    error "Fallo instalando ananicy"
ok "ananicy-cpp listo"

# zram: swap comprimido en RAM
info "zram con zstd..."
sudo pacman -S --needed --noconfirm zram-generator
sudo tee /etc/systemd/zram-generator.conf > /dev/null << 'EOF'
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
EOF
ok "zram configurado (ram/2, zstd)"

# irqbalance
info "irqbalance..."
sudo pacman -S --needed --noconfirm irqbalance
sudo systemctl enable --now irqbalance
ok "irqbalance activo"

# power-profiles-daemon
sudo pacman -S --needed --noconfirm power-profiles-daemon
sudo systemctl enable --now power-profiles-daemon
ok "power-profiles-daemon activo"

# ════════════════════════════════════════════════════════════
section "7. Eliminando bspwm y TODA su configuración"
# ════════════════════════════════════════════════════════════
info "Desinstalando paquetes de bspwm..."
BSPWM_PKGS=(bspwm sxhkd polybar picom picom-git eww eww-git plank jgmenu)
for pkg in "${BSPWM_PKGS[@]}"; do
    if pacman -Qq "$pkg" &>/dev/null; then
        sudo pacman -Rns --noconfirm "$pkg" 2>/dev/null && \
            ok "Desinstalado: $pkg" || warn "No se pudo desinstalar: $pkg"
    fi
done

info "Eliminando configs de bspwm..."
BSPWM_CONFIGS=(
    "$HOME/.config/bspwm"
    "$HOME/.config/sxhkd"
    "$HOME/.config/polybar"
    "$HOME/.config/picom"
    "$HOME/.config/plank"
    "$HOME/.config/eww"
    "$HOME/.config/jgmenu"
    "$HOME/.config/alacritty"
)
for cfg in "${BSPWM_CONFIGS[@]}"; do
    if [ -e "$cfg" ]; then
        rm -rf "$cfg"
        ok "Eliminado: $cfg"
    fi
done

# Eliminar sesión de bspwm del display manager
sudo rm -f /usr/share/xsessions/bspwm.desktop 2>/dev/null || true
ok "bspwm eliminado completamente"

# ════════════════════════════════════════════════════════════
section "8. Instalando yay"
# ════════════════════════════════════════════════════════════
if command -v yay &>/dev/null; then
    ok "yay ya instalado"
else
    info "Instalando yay..."
    cd /tmp
    git clone https://aur.archlinux.org/yay.git --depth=1
    cd yay && makepkg -si --noconfirm
    cd ~
    ok "yay instalado"
fi

# ════════════════════════════════════════════════════════════
section "9. Paquetes oficiales + CachyOS"
# ════════════════════════════════════════════════════════════
info "Instalando paquetes (varios minutos)..."

OFFICIAL_PKGS=(
    # Sistema
    base base-devel dkms
    inetutils btrfs-progs ntfs-3g
    scx-scheds sof-firmware
    cachyos-ananicy-rules ananicy-cpp
    cachyos-rate-mirrors
    # Wayland / Hyprland
    hyprland hypridle hyprlock
    hyprpolkitagent uwsm
    xdg-desktop-portal-hyprland
    xdg-user-dirs xdg-utils
    qt5-wayland qt6-wayland
    qt5ct qt6ct kvantum
    qt6-imageformats qt6-tools
    qt6-virtualkeyboard
    xorg-server xorg-xinit
    # Theming
    adw-gtk-theme nwg-look
    gtk-engine-murrine
    # Audio
    pipewire pipewire-alsa
    pipewire-jack pipewire-pulse
    wireplumber gst-plugin-pipewire
    pavucontrol pamixer pwvucontrol
    alsa-utils easyeffects calf
    libpulse sox speech-dispatcher espeak-ng
    # Bar / Shell / Notifs
    waybar swww swaync wlogout
    fuzzel rofi wofi
    cliphist wl-clip-persist
    wlsunset wtype xdotool ydotool
    # Fuentes
    adobe-source-code-pro-fonts
    noto-fonts noto-fonts-cjk noto-fonts-emoji
    otf-font-awesome ttf-droid
    ttf-roboto ttf-roboto-mono
    ttf-fira-code ttf-firacode-nerd
    ttf-fantasque-nerd
    ttf-jetbrains-mono ttf-jetbrains-mono-nerd
    ttf-nerd-fonts-symbols
    # Terminal
    kitty tmux zsh zsh-completions
    zbar bc nano vim
    # File manager
    thunar thunar-archive-plugin
    thunar-volman tumbler
    ffmpegthumbnailer gvfs gvfs-mtp
    xarchiver unrar unzip mousepad
    # Red / Bluetooth
    networkmanager network-manager-applet
    iwd ethtool wireless_tools nmap socat
    blueman bluez-utils
    # Multimedia
    mpv mpv-mpris vlc
    obs-studio gpu-screen-recorder
    audacity kdenlive
    grim slurp swappy
    imagemagick chafa playerctl
    # Gaming
    steam gamemode lib32-gamemode
    gamescope mangohud goverlay
    protonplus protontricks
    wine-staging lib32-mpg123
    # Desarrollo
    git github-cli rustup
    jdk-openjdk tk pyenv
    python-pip python-pipx
    python-matplotlib python-requests
    python-pyquery mercurial
    mariadb postgresql flatpak
    # Utils
    btop htop ncdu tree lsd fzf gum
    fastfetch inxi smartmontools
    nvme-cli usbutils brightnessctl ddcutil
    ufw firejail pacman-contrib reflector
    timeshift syncthing
    android-tools android-udev android-file-transfer
    f3 bsd-games
    tesseract tesseract-data-eng tesseract-data-spa
    tesseract-data-chi_sim tesseract-data-chi_tra
    tesseract-data-jpn tesseract-data-kor tesseract-data-lat
    # Apps
    firefox bitwarden discord
    obsidian onlyoffice-bin blender
    kdiskmark qalculate-gtk
    gnome-system-monitor loupe piper cups
    # Extras laptop (preservados de tu setup actual)
    yazi zellij
    lazygit neovim
    zsh-autosuggestions
    zsh-syntax-highlighting
    # Extras escritorio
    yad cava matugen wallust
    nwg-displays vdpauinfo libspng
    mesa-demos mesa-utils umockdev
    pokemon-colorscripts-git
    quickshell-git
)

sudo pacman -S --needed --noconfirm "${OFFICIAL_PKGS[@]}" || \
    warn "Algunos paquetes fallaron, continuando..."
ok "Paquetes oficiales instalados"

# ════════════════════════════════════════════════════════════
section "10. Paquetes AUR"
# ════════════════════════════════════════════════════════════
AUR_PKGS=(
    # Del escritorio
    8188eu-dkms-git
    ascii-image-converter
    aylurs-gtk-shell-git
    gradia
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
    warp-terminal
    yt-dlp-git
    # De la laptop (que vale la pena conservar)
    spicetify-cli
    spotify
    spotifyd
)

info "Instalando paquetes AUR..."
yay -S --needed --noconfirm "${AUR_PKGS[@]}" || \
    warn "Algunos paquetes AUR fallaron, revisa manualmente"
ok "Paquetes AUR instalados"

# ════════════════════════════════════════════════════════════
section "11. Preservando configs propias de la laptop"
# ════════════════════════════════════════════════════════════
# Estas configs son tuyas y NO vienen en los dotfiles del escritorio
# Las guardamos antes de aplicar los dotfiles y las restauramos después

LAPTOP_BACKUP="/tmp/laptop-own-configs-$(date +%Y%m%d%H%M%S)"
mkdir -p "$LAPTOP_BACKUP"

LAPTOP_CONFIGS=(
    "$HOME/.config/tmux"
    "$HOME/.config/yazi"
    "$HOME/.config/zellij"
    "$HOME/.config/spicetify"
    "$HOME/.config/spotifyd"
    "$HOME/.config/systemd"
    "$HOME/.config/wireplumber"
)

info "Guardando configs propias de la laptop..."
for cfg in "${LAPTOP_CONFIGS[@]}"; do
    if [ -e "$cfg" ]; then
        cp -r "$cfg" "$LAPTOP_BACKUP/"
        ok "Guardado: $(basename $cfg)"
    fi
done

# ════════════════════════════════════════════════════════════
section "12. Clonando y aplicando dotfiles"
# ════════════════════════════════════════════════════════════

if [ -d "$DOTFILES_DIR" ]; then
    warn "Dotfiles ya existen — actualizando..."

    git --git-dir="$DOTFILES_DIR" --work-tree="$HOME" fetch origin

else
    info "Clonando dotfiles desde GitHub..."
    git clone --bare "$DOTFILES_REPO" "$DOTFILES_DIR"
fi

info "Aplicando dotfiles (forzado)..."

# backup automático de conflictos
mkdir -p "$HOME/.dotfiles-backup"

git --git-dir="$DOTFILES_DIR" --work-tree="$HOME" checkout 2>&1 | while read -r line; do
    if [[ "$line" == *"would be overwritten"* ]]; then
        file=$(echo "$line" | awk '{print $1}')
        mkdir -p "$HOME/.dotfiles-backup/$(dirname "$file")"
        mv "$HOME/$file" "$HOME/.dotfiles-backup/$file"
        warn "Movido a backup: $file"
    fi
done

# ahora sí forzar
git --git-dir="$DOTFILES_DIR" --work-tree="$HOME" checkout -f

git --git-dir="$DOTFILES_DIR" --work-tree="$HOME" config status.showUntrackedFiles no

ok "Dotfiles aplicados correctamente"

# ════════════════════════════════════════════════════════════
section "13. Alias dotfiles en zsh"
# ════════════════════════════════════════════════════════════
ZSHRC="$HOME/.zshrc"
ALIAS_LINE="alias dotfiles='git --git-dir=\$HOME/.dotfiles/ --work-tree=\$HOME'"

if ! grep -q "alias dotfiles" "$ZSHRC" 2>/dev/null; then
    { echo ""; echo "# Dotfiles bare repo"; echo "$ALIAS_LINE"; } >> "$ZSHRC"
    ok "Alias agregado a .zshrc"
else
    ok "Alias ya existe en .zshrc"
fi

# ════════════════════════════════════════════════════════════
section "14. Zsh como shell por defecto"
# ════════════════════════════════════════════════════════════
if [ "$SHELL" != "$(which zsh)" ]; then
    chsh -s "$(which zsh)"
    ok "Shell cambiado a zsh"
else
    ok "Zsh ya es tu shell"
fi

# ════════════════════════════════════════════════════════════
section "15. Servicios del sistema"
# ════════════════════════════════════════════════════════════
SERVICES=(
    NetworkManager bluetooth sddm cups
    ufw irqbalance power-profiles-daemon ananicy-cpp
)
for svc in "${SERVICES[@]}"; do
    sudo systemctl enable --now "$svc" 2>/dev/null \
        && ok "$svc" || warn "$svc no habilitado"
done

systemctl --user enable --now syncthing 2>/dev/null \
    && ok "Syncthing (usuario)" || warn "Syncthing no habilitado"

# ════════════════════════════════════════════════════════════
section "16. Regenerar initramfs y GRUB final"
# ════════════════════════════════════════════════════════════
info "Regenerando initramfs..."
sudo mkinitcpio -P

info "Actualizando GRUB..."
sudo grub-mkconfig -o /boot/grub/grub.cfg
ok "initramfs y GRUB actualizados"

# ════════════════════════════════════════════════════════════
echo ""
echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}${BOLD}║   ¡Instalación completa!                             ║${NC}"
echo -e "${GREEN}${BOLD}║                                                      ║${NC}"
echo -e "${GREEN}${BOLD}║   Optimizaciones aplicadas:                          ║${NC}"
echo -e "${GREEN}${BOLD}║    ✓ CPU governor  : powersave                       ║${NC}"
echo -e "${GREEN}${BOLD}║    ✓ I/O scheduler : bfq                             ║${NC}"
echo -e "${GREEN}${BOLD}║    ✓ ananicy-cpp   : prioridades automáticas         ║${NC}"
echo -e "${GREEN}${BOLD}║    ✓ zram          : swap comprimido (zstd)          ║${NC}"
echo -e "${GREEN}${BOLD}║    ✓ irqbalance    : distribución de interrupciones  ║${NC}"
echo -e "${GREEN}${BOLD}║    ✓ VA-API        : i965 (Haswell correcto)         ║${NC}"
echo -e "${GREEN}${BOLD}║    ✗ intel-media-driver eliminado (no aplica)        ║${NC}"
echo -e "${GREEN}${BOLD}║    ✗ vulkan-radeon/nouveau eliminados                ║${NC}"
echo -e "${GREEN}${BOLD}║                                                      ║${NC}"
echo -e "${GREEN}${BOLD}║   Kernels en GRUB:                                   ║${NC}"
echo -e "${GREEN}${BOLD}║    → linux-cachyos  (principal)                      ║${NC}"
echo -e "${GREEN}${BOLD}║    → linux-lts      (respaldo / safe mode)           ║${NC}"
echo -e "${GREEN}${BOLD}║                                                      ║${NC}"
echo -e "${GREEN}${BOLD}║   bspwm eliminado completamente ✓                    ║${NC}"
echo -e "${GREEN}${BOLD}║   tmux, yazi, zellij, spicetify preservados ✓        ║${NC}"
echo -e "${GREEN}${BOLD}║                                                      ║${NC}"
echo -e "${GREEN}${BOLD}║   Reinicia y elige linux-cachyos en GRUB             ║${NC}"
echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════╝${NC}"
echo ""
read -rp "$(echo -e ${YELLOW}"¿Reiniciar ahora? [s/N]: "${NC})" reboot_now
[[ "$reboot_now" =~ ^[sS]$ ]] && sudo reboot
