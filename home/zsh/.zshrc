export ZSH="$HOME/.oh-my-zsh"

# "random" elige un tema distinto cada vez que arranca zsh, o sea en cada
# terminal nueva. Para volver a uno fijo, poner el nombre aca (ej: "frisk").
ZSH_THEME="alanpeabody"

plugins=(
    git
    archlinux
    zsh-autosuggestions
    zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh

# Check archlinux plugin commands here
# https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/archlinux

# Set-up icons for files/directories in terminal using lsd
alias ls='lsd'
alias l='ls -l'
alias la='ls -a'
alias lla='ls -la'
alias lt='ls --tree'
alias open='xdg-open'

HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory

export PATH="$HOME/.local/bin:$PATH"

# Todo lo de abajo esta guardado con checks porque este .zshrc se comparte entre
# maquinas: si una herramienta no esta instalada, zsh arranca igual y sin ruido.

# FZF key bindings (CTRL R para buscar en el historial)
command -v fzf >/dev/null && source <(fzf --zsh)

# bun
if [ -d "$HOME/.bun" ]; then
    export BUN_INSTALL="$HOME/.bun"
    export PATH="$BUN_INSTALL/bin:$PATH"
    [ -s "$BUN_INSTALL/_bun" ] && source "$BUN_INSTALL/_bun"
fi

# opencode
[ -d "$HOME/.opencode/bin" ] && export PATH="$HOME/.opencode/bin:$PATH"

# nvm
export NVM_DIR="$HOME/.nvm"
if [ -s /usr/share/nvm/init-nvm.sh ]; then
    source /usr/share/nvm/init-nvm.sh
    source /usr/share/nvm/bash_completion
fi

# pyenv
if [ -d "$HOME/.pyenv" ]; then
    export PATH="$HOME/.pyenv/bin:$PATH"
    command -v pyenv >/dev/null && eval "$(pyenv init -)"
fi

# homebrew
[ -x /home/linuxbrew/.linuxbrew/bin/brew ] && \
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
