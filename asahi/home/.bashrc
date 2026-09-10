# ~/.bashrc — Fedora Asahi Remix (MacBook Pro M3 Pro, KDE Plasma).
#
# The quattro version sources /usr/share/omarchy/default/bash/rc, which pulls in
# omarchy's envs/shell/aliases/functions/init. None of that exists on Fedora, so
# the portable subset now lives in ~/.config/shell/ (shared tree) and is sourced
# directly below.
#
# Deliberately NOT carried over from the Arch box:
#   - the conda init block + __conda_hashr no-op  (no miniforge3 here yet)
#   - the grok installer PATH block               (x86_64-only install)
#   - the LM Studio CLI PATH block                (x86_64-only, and needs a GPU)
# Re-add them here if you ever install those, below the shared sources.

# If not running interactively, don't do anything.
[[ $- != *i* ]] && return

# Fedora's global definitions (bash-completion, /etc/profile.d/*.sh).
[[ -f /etc/bashrc ]] && . /etc/bashrc

# --- Shared, cross-host shell config (MaConfig/shared) ---
for _rc in envs aliases init; do
  [[ -r "$HOME/.config/shell/$_rc.bash" ]] && source "$HOME/.config/shell/$_rc.bash"
done
unset _rc

# --- Host-local additions go below this line ---

# Neovim is installed from the official aarch64 tarball into ~/.local/nvim
# (Fedora 43 ships 0.11.x, too old for the vim.pack calls in our init.lua).
# bootstrap.sh symlinks the binary into ~/.local/bin, which envs.bash adds to
# PATH, so nothing more is needed here.
