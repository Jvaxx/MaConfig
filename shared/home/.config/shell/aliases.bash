# Portable aliases. Sourced by ~/.bashrc on every host.
# Distilled from /usr/share/omarchy/default/bash/aliases, minus everything that
# calls an omarchy-* binary (omarchy-agent, herdr, tdl, rails, try...).
# Every block is guarded so a missing tool degrades instead of erroring.

# --- File system ---
if command -v eza >/dev/null 2>&1; then
  alias ls='eza -lh --group-directories-first --icons=auto'
  alias lsa='ls -a'
  alias lt='eza --tree --level=2 --long --icons --git'
  alias lta='lt -a'
fi

if command -v fzf >/dev/null 2>&1; then
  if command -v bat >/dev/null 2>&1; then
    alias ff="fzf --preview 'bat --style=numbers --color=always {}'"
  else
    alias ff="fzf --preview 'cat {}'"
  fi
  alias eff='$EDITOR "$(ff)"'
fi

# zoxide-backed cd: plain `cd` when the path exists, fuzzy jump otherwise.
if command -v zoxide >/dev/null 2>&1; then
  alias cd="zd"
  zd() {
    if (( $# == 0 )); then
      builtin cd ~ || return
    elif [[ -d $1 ]]; then
      builtin cd "$1" || return
    else
      if ! z "$@"; then
        echo "Error: Directory not found"
        return 1
      fi
      printf "\U000F17A9 "
      pwd
    fi
  }
fi

open() (
  xdg-open "$@" >/dev/null 2>&1 &
)

# --- Directories ---
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# --- Tools ---
alias d='docker'
alias t='tmux attach || tmux new -s Work'
n() { if [ "$#" -eq 0 ]; then command nvim . ; else command nvim "$@"; fi; }

# --- Git ---
alias g='git'
alias gcm='git commit -m'
alias gcam='git commit -a -m'
alias gcad='git commit -a --amend'

# --- Python ---
alias v.='source .venv/bin/activate'
