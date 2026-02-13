
# zsh history =================================================================
HISTSIZE=10000000
SAVEHIST=10000000
HISTFILE="$HOME/.histfile"

# zsh options =================================================================
setopt SHAREHISTORY
setopt EXTENDEDHISTORY
setopt HISTIGNORESPACE
setopt HISTREDUCEBLANKS
setopt INCAPPENDHISTORYTIME



# Custom shit starts here =====================================================
[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/shell/aliasrc" ] && source "${XDG_CONFIG_HOME:-$HOME/.config}/shell/aliasrc"
[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/shell/env-var" ] && source "${XDG_CONFIG_HOME:-$HOME/.config}/shell/env-var"

# zsh plugins =================================================================
source ~/.local/src/zsh-autosuggestions/zsh-autosuggestions.zsh
source ~/.local/src/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source ~/.local/src/zsh-vi-mode/zsh-vi-mode.zsh

# Tab completion capital and small letters to be treated as same
autoload -Uz compinit
compinit
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*'


# cause zsh-vi-mode fucks up some keybindings
function zvm_after_init() {
  bindkey '^R' fzf-history-widget
}


# adding fzf shell integration
source <(fzf --zsh)


# Display Pokemon
# pokemon-colorscripts --no-title -r 1,3,6

eval "$(zoxide init --cmd cd zsh)"
eval "$(starship init zsh)"
