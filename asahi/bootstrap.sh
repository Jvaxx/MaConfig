#!/usr/bin/env bash
# Installation des paquets sur Fedora Asahi Remix (aarch64, KDE Plasma).
# Usage: ./bootstrap.sh [--dry-run] [--tier N]... [--no-copr] [--skip-manual]
#
# Idempotent : relancer ne casse rien. Chaque paquet est tenté séparément, donc
# un nom absent des dépôts ne fait pas échouer tout le lot — il est signalé en
# fin de course. C'est voulu : les dépôts aarch64 d'Asahi suivent Fedora mais on
# ne veut pas d'un `dnf install` monolithique qui abandonne au premier manquant.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKGFILE="$HERE/packages.dnf"

DRY=0; NO_COPR=0; SKIP_MANUAL=0; TIERS=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)      DRY=1 ;;
    --no-copr)      NO_COPR=1 ;;
    --skip-manual)  SKIP_MANUAL=1 ;;
    --tier)         TIERS="$TIERS $2"; shift ;;
    *) echo "option inconnue: $1"; exit 1 ;;
  esac
  shift
done

[[ -f $PKGFILE ]] || { echo "packages.dnf introuvable"; exit 1; }

FAILED=()
run() { if (( DRY )); then echo "  [dry] $*"; else "$@"; fi; }

say() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m  !! %s\033[0m\n' "$*"; }

# ---------------------------------------------------------------------
# 0. Garde-fous
# ---------------------------------------------------------------------
if [[ $(uname -m) != aarch64 ]]; then
  warn "architecture $(uname -m), ce script cible aarch64 (Asahi). On continue quand même."
fi
# En --dry-run on n'exige pas dnf : ça permet de relire le plan d'installation
# depuis la machine Arch, là où ce fichier est édité.
if ! command -v dnf >/dev/null; then
  if (( DRY )); then
    warn "dnf absent — simulation seulement."
  else
    echo "dnf introuvable — ce script est pour Fedora."; exit 1
  fi
fi

# ---------------------------------------------------------------------
# 1. Paquets dnf, section par section
# ---------------------------------------------------------------------
current_mode=""; current_arg=""; current_tier=0
batch=()

want_tier() {
  [[ -z ${TIERS// /} ]] && return 0
  [[ " $TIERS " == *" $current_tier "* ]]
}

flush() {
  (( ${#batch[@]} )) || return 0
  if ! want_tier; then batch=(); return 0; fi

  if [[ $current_mode == copr ]]; then
    if (( NO_COPR )); then
      warn "COPR $current_arg ignoré (--no-copr) : ${batch[*]}"
      batch=(); return 0
    fi
    say "COPR $current_arg"
    run sudo dnf -y copr enable "$current_arg" || warn "copr enable $current_arg a échoué"
  fi

  for p in "${batch[@]}"; do
    if command -v rpm >/dev/null 2>&1 && rpm -q "$p" >/dev/null 2>&1; then
      echo "  déjà là   $p"
      continue
    fi
    echo "  install   $p"
    if ! run sudo dnf -y install "$p" >/dev/null 2>&1; then
      warn "échec: $p"
      FAILED+=("$p")
    fi
  done
  batch=()
}

while IFS= read -r line; do
  case "$line" in
    *"TIER 1"*) flush; current_tier=1; say "TIER 1 — shell & CLI core"; continue ;;
    *"TIER 2"*) flush; current_tier=2; say "TIER 2 — toolchains de dev";  continue ;;
    *"TIER 3"*) flush; current_tier=3; say "TIER 3 — terminal, polices, saisie"; continue ;;
    *"TIER 4"*) flush; current_tier=4; say "TIER 4 — GUI sans GPU";       continue ;;
  esac

  if [[ $line == '#@'* ]]; then
    flush
    read -r tag arg <<<"${line#\#@}"
    current_mode="$tag"; current_arg="${arg:-}"
    continue
  fi

  line="${line%%#*}"; line="${line// /}"
  [[ -z $line ]] && continue
  [[ $current_mode == manual ]] && continue
  batch+=("$line")
done < "$PKGFILE"
flush

# ---------------------------------------------------------------------
# 2. Neovim >= 0.12 (tarball officielle aarch64)
# ---------------------------------------------------------------------
# Indispensable : init.lua appelle vim.pack.add(), introduit en 0.12, alors que
# Fedora 43 ne fournit que 0.11.x. On installe hors dnf pour ne pas se battre
# avec le paquet distribution.
install_nvim() {
  local want="${NVIM_VERSION:-stable}"
  local prefix="$HOME/.local/nvim"
  local url="https://github.com/neovim/neovim/releases/download/${want}/nvim-linux-arm64.tar.gz"

  if command -v nvim >/dev/null 2>&1; then
    local have; have="$(nvim --version | head -1 | grep -oE '[0-9]+\.[0-9]+')"
    if [[ -n $have ]] && awk -v v="$have" 'BEGIN{exit !(v+0 >= 0.12)}'; then
      echo "  nvim $have déjà >= 0.12, rien à faire"
      return 0
    fi
  fi

  say "Neovim $want (tarball aarch64) -> $prefix"
  (( DRY )) && { echo "  [dry] curl $url"; return 0; }

  local tmp; tmp="$(mktemp -d)"
  if ! curl -fsSL "$url" -o "$tmp/nvim.tar.gz"; then
    warn "téléchargement de $url impossible"; rm -rf "$tmp"; FAILED+=("neovim"); return 1
  fi
  tar -xzf "$tmp/nvim.tar.gz" -C "$tmp"
  rm -rf "$prefix"
  mkdir -p "$(dirname "$prefix")"
  mv "$tmp"/nvim-linux-arm64 "$prefix"
  rm -rf "$tmp"

  mkdir -p "$HOME/.local/bin"
  ln -sfn "$prefix/bin/nvim" "$HOME/.local/bin/nvim"
  echo "  $("$prefix/bin/nvim" --version | head -1)"
}
install_nvim

# ---------------------------------------------------------------------
# 3. Outils hors dépôts
# ---------------------------------------------------------------------
if (( ! SKIP_MANUAL )); then
  say "Outils hors dépôts"

  if ! command -v mise >/dev/null 2>&1; then
    echo "  mise"
    run bash -c 'curl -fsSL https://mise.run | sh' || FAILED+=("mise")
  fi

  if ! command -v uv >/dev/null 2>&1; then
    echo "  uv"
    run bash -c 'curl -LsSf https://astral.sh/uv/install.sh | sh' || FAILED+=("uv")
  fi

  # Les trois suivants n'existent ni en RPM ni en COPR fiable pour aarch64.
  if command -v cargo >/dev/null 2>&1; then
    for c in dua-cli diskonaut tree-sitter-cli; do
      command -v "${c%-cli}" >/dev/null 2>&1 && continue
      echo "  cargo install $c"
      run cargo install "$c" || FAILED+=("$c")
    done
  else
    warn "cargo absent : dua-cli / diskonaut / tree-sitter-cli non installés"
  fi

  if command -v go >/dev/null 2>&1 && ! command -v lazydocker >/dev/null 2>&1; then
    echo "  lazydocker"
    run go install github.com/jesseduffield/lazydocker@latest || FAILED+=("lazydocker")
  fi

  if command -v flatpak >/dev/null 2>&1; then
    run flatpak remote-add --if-not-exists --user flathub \
      https://dl.flathub.org/repo/flathub.flatpakrepo >/dev/null 2>&1
    for app in org.localsend.localsend_app md.obsidian.Obsidian org.signal.Signal; do
      flatpak info "$app" >/dev/null 2>&1 && { echo "  déjà là   $app"; continue; }
      echo "  flatpak   $app"
      run flatpak install -y --user flathub "$app" >/dev/null 2>&1 \
        || warn "$app indisponible en aarch64 (attendu pour certains)"
    done
  else
    warn "flatpak absent : localsend / obsidian / signal non installés"
  fi
fi

# ---------------------------------------------------------------------
# 4. Bilan
# ---------------------------------------------------------------------
say "Bilan"
if (( ${#FAILED[@]} )); then
  echo "  Non installés (${#FAILED[@]}) :"
  printf '    - %s\n' "${FAILED[@]}"
  echo
  echo "  Vérifie avec: dnf search <nom>   /   https://packages.fedoraproject.org"
else
  echo "  Tout est passé."
fi
echo
echo "  Suite : ./restore.sh   puis   RESTORE.md pour les étapes manuelles (XKB/Plasma)."
