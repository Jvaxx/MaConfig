# ~/.bash_profile — Fedora Asahi Remix.
# Set user tool paths even for non-interactive login shells; no tool activation.
[[ ! -r "$HOME/.config/shell/path.bash" ]] || source "$HOME/.config/shell/path.bash"
[[ ! -r "$HOME/.bashrc" ]] || source "$HOME/.bashrc"
# Machine-local login customisations, deliberately outside MANIFEST.
[[ ! -r "$HOME/.bash_profile.local" ]] || source "$HOME/.bash_profile.local"
