export PATH="$HOME/.local/share/bob/nvim-bin:$PATH"
export EDITOR=nvim
export VISUAL="$EDITOR"

# Les couleurs des commandes macos
export CLICOLOR=1
export LSCOLORS="exfxcxdxbxegedabagacad"
export TERM=xterm-256color

alias ls='ls -lG'
alias lsa='ls -laG'

alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

alias n='nvim .'

# Mode edition de commande:
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey -v
bindkey -M vicmd "^V" edit-command-line

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/opt/homebrew/Caskroom/miniforge/base/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/opt/homebrew/Caskroom/miniforge/base/etc/profile.d/conda.sh" ]; then
        . "/opt/homebrew/Caskroom/miniforge/base/etc/profile.d/conda.sh"
    else
        export PATH="/opt/homebrew/Caskroom/miniforge/base/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<

# Coloration synthaxique après avoir ajouté zsh-syntax-highlighting par homebrew
source $(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh


# Added by LM Studio CLI (lms)
export PATH="$PATH:/Users/jvz/.lmstudio/bin"
# End of LM Studio CLI section

eval "$(starship init zsh)"
