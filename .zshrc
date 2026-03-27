# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH
export PATH="$HOME/.local/bin:$PATH"

export ZSH="$HOME/.oh-my-zsh"
export MOZ_ENABLE_WAYLAND=1
export PATH=~/.npm-global/bin:$PATH

ZSH_THEME="gnzh"

plugins=(
    git
    archlinux
    zsh-autosuggestions
    zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh

# Check archlinux plugin commands here
# https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/archlinux

# Display Pokemon-colorscripts
# Project page: https://gitlab.com/phoneybadger/pokemon-colorscripts#on-other-distros-and-macos
#pokemon-colorscripts --no-title -s -r #without fastfetch
pokemon-colorscripts --no-title -s -r | fastfetch -c $HOME/.config/fastfetch/config-pokemon.jsonc --logo-type file-raw --logo-height 10 --logo-width 5 --logo -

# fastfetch. Will be disabled if above colorscript was chosen to install
#fastfetch -c $HOME/.config/fastfetch/config-compact.jsonc

# Set-up icons for files/directories in terminal using lsd
alias ls='lsd'
alias l='ls -l'
alias la='ls -a'
alias lla='ls -la'
alias lt='ls --tree'
alias rthunar='sudo --preserve-env=WAYLAND_DISPLAY,XDG_RUNTIME_DIR thunar'
alias cls='clear'
alias ff='clear && fastfetch'

#------------------------------------------------------------------------------------------------------------------------
#ACTUALIZACIÓN DEL SISTEMA (PACMAN + AUR)
# Aliases de actualización del sistema
alias update='clear && ~/update.sh && clear && fastfetch'
alias upd='yay -Syu --noconfirm'  # Actualización rápida sin confirmación
alias updsys='sudo pacman -Syu'    # Solo paquetes oficiales
alias updaur='yay -Sua'            # Solo paquetes de AUR

# Actualizar aplicaciones específicas
alias updis='yay -S discord --noconfirm && clear && fastfetch && echo "✓ Discord actualizado"'
alias upvsc='yay -S visual-studio-code-bin --noconfirm && clear && fastfetch && echo "✓ VSCode actualizado"'

# Limpieza del sistema
alias cleanup='yay -Sc --noconfirm && yay -Yc --noconfirm && echo "✓ Caché limpiada"'
alias orphans='sudo pacman -Rns $(pacman -Qtdq) 2>/dev/null || echo "No hay paquetes huérfanos"'

#------------------------------------------------------------------------------------------------------------------------
# ALIAS PARA GIT
alias gits='git status'
alias gitp='git pull'
alias gitm='git commit -m "$1"'
alias gitps='git push'

#Alias de Git add, commit y push
gitacp() {
    echo "\n\033[1;34m📦 Archivos modificados:\033[0m"
    git status --porcelain
    
    echo "\n\033[1;36m✓ Selecciona los archivos a subir (TAB para multi-select, ENTER para confirmar):\033[0m"
    git status --porcelain | cut -c4- | fzf -m | xargs -r git add
    
    if [ $? -ne 0 ]; then
        echo "\n\033[1;31m✗ Operación cancelada\033[0m\n"
        return 1
    fi
    
    echo "\n\033[1;33m📝 Committing changes...\033[0m"
    git commit -m "$1" || { echo "\n\033[1;31m✗ Error al hacer commit\033[0m\n"; return 1; }
    
    echo "\n\033[1;32m🚀 Pushing to remote...\033[0m"
    if ! git push; then
        echo "\n\033[1;33m⚠️  Push falló. Intentando con --set-upstream...\033[0m"
        local branch=$(git branch --show-current)
        git push --set-upstream origin "$branch" || { echo "\n\033[1;31m✗ Error al hacer push\033[0m\n"; return 1; }
    fi
    
    echo "\n\033[1;32m✓ Completado!\033[0m\n"
}

#alias mysql
alias mc='mycli -u root -h 127.0.0.1'

# Función para modelo IA GLaDOS
glados() {
    local original_dir="$PWD"
    cd ~/GlaDOS && source venv/bin/activate && python glados.py
    deactivate 2>/dev/null
    cd "$original_dir"
}
alias gl='glados'

alias windows='sudo grub-reboot "Windows Boot Manager (en /dev/sdc1)" && reboot'

#

# Set-up FZF key bindings (CTRL R for fuzzy history finder)
source <(fzf --zsh)

HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory

# --- PYENV ---
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"

if command -v pyenv >/dev/null 2>&1; then
  eval "$(pyenv init - zsh)"
fi

export PYENV_REHASH_TIMEOUT=5

# Following line was automatically added by arttime installer
export MANPATH=/home/sadrach/.local/share/man:$MANPATH
alias dotfiles='git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'
alias dotfiles='git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'
