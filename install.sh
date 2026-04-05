#!/usr/bin/env bash

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
section() { echo -e "\n${BLUE}${BOLD}━━━  $1  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$SCRIPT_DIR"
BACKUP_ROOT="$HOME/.dotfiles-backup"
MARKER_FILE="$HOME/.local/share/sadrach-dotfiles-installed"
ASSUME_YES=false
SKIP_PACKAGES=false
MODE="auto"

usage() {
  cat <<HELP
Uso: $(basename "$0") [opciones]

Opciones:
  --install         Forzar modo instalacion inicial
  --update          Forzar modo actualizacion
  --yes             No pedir confirmaciones interactivas
  --skip-packages   No instalar paquetes
  -h, --help        Mostrar esta ayuda

Modo auto:
  Si existe $MARKER_FILE => update
  Si no existe            => install
HELP
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --install) MODE="install" ;;
    --update) MODE="update" ;;
    --yes|-y) ASSUME_YES=true ;;
    --skip-packages) SKIP_PACKAGES=true ;;
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
  read -rp "$(echo -e ${YELLOW}"$prompt [s/N]: "${NC})" ans
  [[ "$ans" =~ ^[sS]$ ]] || { echo "Cancelado."; exit 0; }
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

install_packages() {
  local pkgm="$1"

  if $SKIP_PACKAGES; then
    warn "Saltando instalacion de paquetes (--skip-packages)."
    return
  fi

  section "Dependencias base"
  case "$pkgm" in
    pacman)
      info "Instalando paquetes base con pacman..."
      sudo pacman -Syu --noconfirm
      sudo pacman -S --needed --noconfirm \
        git rsync curl wget zsh \
        hyprland hypridle hyprlock \
        waybar swaync cliphist swww \
        kitty fzf ripgrep

      if ! command -v yay >/dev/null 2>&1; then
        info "Instalando yay..."
        local tmpdir
        tmpdir="$(mktemp -d)"
        git clone https://aur.archlinux.org/yay.git "$tmpdir/yay" --depth=1
        (cd "$tmpdir/yay" && makepkg -si --noconfirm)
        rm -rf "$tmpdir"
      fi
      ;;
    apt)
      info "Instalando paquetes base con apt..."
      sudo apt update
      sudo apt install -y git rsync curl wget zsh
      warn "Hyprland/Waybar/Quickshell pueden requerir repos extra en Debian/Ubuntu."
      ;;
    dnf)
      info "Instalando paquetes base con dnf..."
      sudo dnf install -y git rsync curl wget zsh
      warn "Hyprland/Waybar/Quickshell pueden requerir repos extra en Fedora."
      ;;
    *)
      warn "No se detecto gestor de paquetes soportado."
      ;;
  esac
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

  info "Sincronizando .config ..."
  sync_directory_contents "$REPO_DIR/.config" "$HOME/.config"

  if [[ -f "$REPO_DIR/.zshrc" ]]; then
    backup_target "$REPO_DIR/.zshrc" "$HOME/.zshrc"
  fi

  if [[ -d "$REPO_DIR/wallpapers" ]]; then
    info "Sincronizando wallpapers estaticos del repo..."
    mkdir -p "$HOME/Pictures/wallpapers"
    rsync -a "$REPO_DIR/wallpapers/" "$HOME/Pictures/wallpapers/"
    ok "Wallpapers sincronizados"
  fi
}

enable_services_best_effort() {
  section "Servicios (best-effort)"
  for svc in NetworkManager bluetooth; do
    if systemctl list-unit-files | grep -q "^${svc}\\.service"; then
      sudo systemctl enable --now "$svc" || warn "No se pudo habilitar $svc"
    fi
  done

  if systemctl --user list-unit-files 2>/dev/null | grep -q "syncthing.service"; then
    systemctl --user enable --now syncthing || warn "No se pudo habilitar syncthing (user)"
  fi
}

set_default_shell() {
  section "Shell por defecto"
  if command -v zsh >/dev/null 2>&1; then
    if [[ "$SHELL" != "$(command -v zsh)" ]]; then
      info "Cambiando shell a zsh..."
      chsh -s "$(command -v zsh)" || warn "No se pudo cambiar shell automaticamente"
    else
      ok "zsh ya es shell por defecto"
    fi
  fi
}

main() {
  section "Dotfiles Installer"
  info "Repositorio: $REPO_DIR"
  info "Modo: $MODE"
  warn "Este script hace backup de archivos que sobrescribe en $BACKUP_ROOT"

  confirm_or_exit "Continuar"

  local pkgm
  pkgm="$(detect_pkg_manager)"
  info "Gestor de paquetes detectado: $pkgm"

  install_packages "$pkgm"

  if [[ "$MODE" == "update" ]]; then
    section "Actualizando repo"
    if [[ -d "$REPO_DIR/.git" ]]; then
      info "Haciendo git pull en el repo actual..."
      (cd "$REPO_DIR" && git pull --ff-only) || warn "git pull no se pudo completar (revisa conflictos/remoto)."
    else
      warn "No se detecto .git en $REPO_DIR, se omite pull."
    fi
  fi

  apply_dotfiles
  enable_services_best_effort
  set_default_shell

  mkdir -p "$(dirname "$MARKER_FILE")"
  printf "mode=%s\ndate=%s\nrepo=%s\n" "$MODE" "$(date -Iseconds)" "$REPO_DIR" > "$MARKER_FILE"

  echo
  ok "Proceso completado en modo $MODE"
  info "Si quieres forzar update: ./install.sh --update"
  info "Si quieres instalacion limpia: ./install.sh --install"
}

main "$@"
