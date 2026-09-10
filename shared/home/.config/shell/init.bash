# Portable prompt/tool initialisation. Sourced last by ~/.bashrc.
# Mirrors /usr/share/omarchy/default/bash/init without the omarchy specifics.

if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate bash)"
  # mise wants command hashing off so shims resolve after a version switch.
  set +h
fi

if [[ $- == *i* ]] && [[ ${TERM:-} != "dumb" ]] && command -v starship >/dev/null 2>&1; then
  eval "$(starship init bash)"
fi

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init bash)"
fi

if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook bash)"
fi

# Modern fzf emits its own integration; no distro-specific paths required.
# Keep a fallback for older installs, loading at most one copy.
if command -v fzf >/dev/null 2>&1; then
  if _fzf_init="$(fzf --bash 2>/dev/null)"; then
    eval "$_fzf_init"
  else
    for _d in /usr/share/fzf /usr/share/fzf/shell "$HOME/.fzf/shell"; do
      if [[ -f $_d/completion.bash && -f $_d/key-bindings.bash ]]; then
        source "$_d/completion.bash"
        source "$_d/key-bindings.bash"
        break
      fi
    done
    unset _d
  fi
  unset _fzf_init
fi

if command -v gh >/dev/null 2>&1; then
  eval "$(gh completion -s bash)" 2>/dev/null || true
fi
