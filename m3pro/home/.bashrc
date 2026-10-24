# Omarchy environment (OMARCHY_PATH + PATH), needed even for non-interactive shells
[[ -r /usr/share/omarchy/default/bash/env-bootstrap ]] && source /usr/share/omarchy/default/bash/env-bootstrap

# If not running interactively, don't do anything else (leave this above the rc source)
[[ $- != *i* ]] && return

# All the default Omarchy aliases and functions
# (don't mess with these directly, just overwrite them here!)
source "$OMARCHY_PATH/default/bash/rc"

# Add your own exports, aliases, and functions here.
#
# Make an alias for invoking commands you use constantly
# alias p='python'
alias v.='source .venv/bin/activate'

# Quattro also sets up conda (miniforge), grok, LM Studio and direnv here.
# None is installed on this machine (LM Studio has no aarch64 build), so only
# direnv is kept, behind a guard until it is installed.
if command -v direnv &> /dev/null; then
  eval "$(direnv hook bash)"
fi
