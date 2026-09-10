# ~/.bashrc — Fedora Asahi Remix / KDE. No Omarchy runtime dependencies.
[[ $- != *i* ]] && return

# Fedora global definitions, including distribution bash-completion.
[[ ! -r /etc/bashrc ]] || source /etc/bashrc

for _rc in envs aliases; do
  [[ ! -r "$HOME/.config/shell/$_rc.bash" ]] || source "$HOME/.config/shell/$_rc.bash"
done
unset _rc

# Preserve Fedora's local extension point. These files are deliberately not
# managed by MANIFEST: machine-local secrets/settings must not enter Git.
for _rc in "$HOME"/.bashrc.d/*; do
  [[ ! -f $_rc || ! -r $_rc ]] || source "$_rc"
done
unset _rc

# Keep the NVM installation already present on this Mac. Do not download NVM,
# replace its default Node version, or discard a custom NVM_DIR.
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
if ! declare -F nvm >/dev/null && [[ -s $NVM_DIR/nvm.sh ]]; then
  source "$NVM_DIR/nvm.sh"
fi
[[ ! -s $NVM_DIR/bash_completion ]] || source "$NVM_DIR/bash_completion"

# Prompt, completions, zoxide, direnv and optional mise activation.
[[ ! -r "$HOME/.config/shell/init.bash" ]] || source "$HOME/.config/shell/init.bash"

# Untracked final overrides (never automatically copied into the repository).
[[ ! -r "$HOME/.bashrc.local" ]] || source "$HOME/.bashrc.local"
