# Portable environment. Sourced by ~/.bashrc on every host.
# Replaces the parts of /usr/share/omarchy/default/bash/envs that are not
# tied to omarchy-* binaries.

export EDITOR="${EDITOR:-nvim}"
export VISUAL="$EDITOR"
export SUDO_EDITOR="$EDITOR"

# bat as the pager for man(1) — same look as on the Omarchy box.
if command -v bat >/dev/null 2>&1; then
  export BAT_THEME=ansi
  export MANROFFOPT="-c"
  export MANPAGER="sh -c 'col -bx | bat -l man -p'"
elif command -v batcat >/dev/null 2>&1; then
  # Debian/Ubuntu name; harmless elsewhere.
  export MANROFFOPT="-c"
  export MANPAGER="sh -c 'col -bx | batcat -l man -p'"
fi

# Locale: /etc/profile.d/locale.sh only runs for login shells, so SSH and other
# non-login interactive shells can land in the C locale, where printf emits
# \u escapes literally instead of the character.
if [ -z "${LANG:-}" ]; then
  [ -r /etc/locale.conf ] && . /etc/locale.conf
  LANG="${LANG:-C.UTF-8}"
  export LANG
fi

# Also used by .bash_profile for non-interactive login shells.
[[ ! -r "$HOME/.config/shell/path.bash" ]] || source "$HOME/.config/shell/path.bash"
