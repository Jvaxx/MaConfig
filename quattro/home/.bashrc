# If not running interactively, don't do anything (leave this at the top of this file)
[[ $- != *i* ]] && return

# All the default Omarchy aliases and functions
# (don't mess with these directly, just overwrite them here!)
# /etc/omarchy.conf is written by omarchy-dev-link. When absent, force the
# package default instead of preserving a stale inherited dev-link value before
# we decide which rc file to source.
if [[ -f /etc/omarchy.conf ]]; then
  source /etc/omarchy.conf
  export OMARCHY_PATH="${OMARCHY_PATH:-/usr/share/omarchy}"
else
  export OMARCHY_PATH=/usr/share/omarchy
fi
source "$OMARCHY_PATH/default/bash/rc"

# Add your own exports, aliases, and functions here.
#
# Make an alias for invoking commands you use constantly
# alias p='python'
alias v.='source .venv/bin/activate'

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/home/jvz/miniforge3/bin/conda' 'shell.bash' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/home/jvz/miniforge3/etc/profile.d/conda.sh" ]; then
        . "/home/jvz/miniforge3/etc/profile.d/conda.sh"
    else
        export PATH="/home/jvz/miniforge3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<

# Omarchy's bash defaults run `set +h` (command hashing off, for mise), so
# conda's `hash -r` on every activate just prints "hashing disabled". There's
# no hash table to clear anyway, so make it a no-op. Must stay below the
# conda block, which redefines this on `conda init`.
__conda_hashr() { :; }


# >>> grok installer >>>
export PATH="$HOME/.grok/bin:$PATH"
[[ -r "$HOME/.grok/completions/bash/grok.bash" ]] && source "$HOME/.grok/completions/bash/grok.bash"
# <<< grok installer <<<

# Added by LM Studio CLI (lms)
export PATH="$PATH:/home/jvz/.lmstudio/bin"
# End of LM Studio CLI section

eval "$(direnv hook bash)"
