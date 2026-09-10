# User tools before distro binaries; safe to source repeatedly and non-interactively.
# Do not source tool activation scripts here (login shells may run remote commands).
_maconfig_prepend_path() {
  local directory=$1 part result=$1
  local -a parts=()
  IFS=: read -r -a parts <<< "${PATH:-}"
  for part in "${parts[@]}"; do
    [[ -z $part || $part == "$directory" ]] && continue
    result+=":$part"
  done
  export PATH="$result"
}
# Reverse priority order, as each call prepends. Respect custom Cargo/Go roots.
# GOPATH can contain multiple roots; Go installs binaries in the first one.
_maconfig_go_root=${GOPATH:-$HOME/go}
_maconfig_prepend_path "${GOBIN:-${_maconfig_go_root%%:*}/bin}"
_maconfig_prepend_path "${CARGO_HOME:-$HOME/.cargo}/bin"
_maconfig_prepend_path "$HOME/bin"
_maconfig_prepend_path "$HOME/.local/bin"
unset _maconfig_go_root
unset -f _maconfig_prepend_path
