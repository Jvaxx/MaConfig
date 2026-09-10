#!/usr/bin/env bash
# Fedora Asahi Remix 44+ / aarch64. Installe les outils, jamais les dotfiles.
# Voir RESTORE.md pour les tiers, les sources et les limites du mode simulation.
set -euo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DRY=0; NO_COPR=0; SKIP_MANUAL=0
TIERS=(); FAILED=(); SKIPPED=()
usage() {
  echo "Usage: $0 [--dry-run] [--tier 1|2|3|4]... [--no-copr] [--skip-manual]"
}
while (( $# )); do
  case "$1" in
    --dry-run) DRY=1 ;;
    --no-copr) NO_COPR=1 ;;
    --skip-manual) SKIP_MANUAL=1 ;;
    --tier)
      [[ ${2:-} =~ ^[1-4]$ ]] || { usage >&2; exit 2; }
      TIERS+=("$2"); shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Option inconnue: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done
want_tier() {
  local tier
  (( ${#TIERS[@]} )) || return 0
  for tier in "${TIERS[@]}"; do [[ $tier == "$1" ]] && return 0; done
  return 1
}
say() { printf '\n==> %s\n' "$*"; }
fail() { printf 'ERREUR: %s\n' "$*" >&2; FAILED+=("$*"); }
run() {
  printf '  '; printf '%q ' "$@"; printf '\n'
  (( DRY )) || "$@"
}
attempt() {
  local label=$1; shift
  if ! run "$@"; then fail "$label"; fi
}

# A dry-run is portable and performs no RPM/Flatpak queries, downloads or writes.
# A real install must be run as the target user, not via sudo ./bootstrap.sh.
ID=; ID_LIKE=; VERSION_ID=
# shellcheck disable=SC1091
[[ ! -r /etc/os-release ]] || source /etc/os-release
if (( ! DRY )); then
  [[ $EUID -ne 0 ]] || { echo "Lancer sans sudo (sudo est utilisé seulement pour dnf)." >&2; exit 1; }
  [[ $(uname -m) == aarch64 ]] || { echo "Architecture requise: aarch64." >&2; exit 1; }
  [[ $ID == fedora || $ID == fedora-asahi-remix || " $ID_LIKE " == *" fedora "* ]] \
    || { echo "Distribution Fedora requise." >&2; exit 1; }
  [[ $VERSION_ID =~ ^[0-9]+$ && $VERSION_ID -ge 44 ]] \
    || { echo "Ce bootstrap cible Fedora 44+ (Neovim >= 0.12)." >&2; exit 1; }
  for cmd in dnf sudo python3; do
    command -v "$cmd" >/dev/null || { echo "Prérequis absent: $cmd" >&2; exit 1; }
  done
fi

# Keep locally installed tools visible during this run, before restoring bashrc.
export PATH="$HOME/.local/bin:${CARGO_HOME:-$HOME/.cargo}/bin:$PATH"
# Make the chroot explicit: derivatives may identify as fedora-asahi-remix.
FEDORA_VERSION=44
if [[ $VERSION_ID =~ ^[0-9]+$ ]] && [[ $ID == fedora || $ID == fedora-asahi-remix || " $ID_LIKE " == *" fedora "* ]]; then
  FEDORA_VERSION=$VERSION_ID
fi
CHROOT="fedora-$FEDORA_VERSION-aarch64"

# Parse and validate the WHOLE package file before executing any command.
# Headers are explicit (#@tier), not inferred from prose comments.
PKGS=(); MODES=(); REPOS=(); PKG_TIERS=()
tier=; mode=; repo=
while IFS= read -r line || [[ -n $line ]]; do
  line="${line%$'\r'}"
  if [[ $line == '#@'* ]]; then
    read -r tag arg extra <<<"${line#\#@}"
    case "$tag" in
      tier)
        [[ ${arg:-} =~ ^[1-4]$ && -z ${extra:-} ]] || { echo "Tier invalide: $line" >&2; exit 2; }
        tier=$arg; mode=; repo= ;;
      repo)
        [[ -n $tier && -z ${arg:-} ]] || { echo "Section invalide: $line" >&2; exit 2; }
        mode=repo; repo= ;;
      copr)
        [[ -n $tier && ${arg:-} =~ ^[a-zA-Z0-9_@.-]+/[a-zA-Z0-9_.:-]+$ && -z ${extra:-} ]] \
          || { echo "COPR invalide: $line" >&2; exit 2; }
        mode=copr; repo=$arg ;;
      *) echo "Directive inconnue: $line" >&2; exit 2 ;;
    esac
    continue
  fi
  line="${line%%#*}"
  # Trim whitespace without word splitting, xargs, or interpreting quotes.
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"
  [[ -n $line ]] || continue
  [[ -n $mode && $line =~ ^[a-zA-Z0-9][a-zA-Z0-9+_.-]*$ ]] \
    || { echo "Paquet/section invalide: $line" >&2; exit 2; }
  PKGS+=("$line"); MODES+=("$mode"); REPOS+=("$repo"); PKG_TIERS+=("$tier")
done < "$HERE/packages.dnf"

say "Paquets Fedora (les erreurs restent visibles)"
declare -A COPR_STATUS=()
for i in "${!PKGS[@]}"; do
  want_tier "${PKG_TIERS[i]}" || continue
  p=${PKGS[i]}; repo=${REPOS[i]}
  if [[ ${MODES[i]} == copr ]]; then
    if (( NO_COPR )); then SKIPPED+=("$p (--no-copr)"); continue; fi
    if [[ ! -v COPR_STATUS[$repo] ]]; then
      if run sudo dnf -y copr enable "$repo" "$CHROOT"; then
        COPR_STATUS[$repo]=ok
      else
        COPR_STATUS[$repo]=failed
        fail "activation COPR $repo"
      fi
    fi
    if [[ ${COPR_STATUS[$repo]} != ok ]]; then
      fail "$p (COPR indisponible)"; continue
    fi
  fi
  attempt "dnf install $p" sudo dnf -y install "$p"
done

# Compare major/minor components, not floating point (0.9 is older than 0.12).
version_at_least() {
  local text=$1 major=$2 minor=$3 patch=${4:-0}
  [[ $text =~ ([0-9]+)\.([0-9]+)\.([0-9]+) ]] || return 1
  local have_major=$((10#${BASH_REMATCH[1]})) have_minor=$((10#${BASH_REMATCH[2]})) have_patch=$((10#${BASH_REMATCH[3]}))
  (( have_major > major || (have_major == major && have_minor > minor) ||
     (have_major == major && have_minor == minor && have_patch >= patch) ))
}
if want_tier 1 && (( ! DRY )); then
  nvim_version="$(nvim --version 2>/dev/null || true)"
  if ! version_at_least "$nvim_version" 0 12; then
    # dnf install need not upgrade an already installed older RPM.
    attempt "mise à jour du RPM Neovim" sudo dnf -y upgrade neovim
    nvim_version="$(nvim --version 2>/dev/null || true)"
    if ! version_at_least "$nvim_version" 0 12; then
      fail "nvim >= 0.12 requis; vérifier PATH/type -a nvim (aucun ancien binaire supprimé)"
    fi
  fi
fi
if want_tier 2 && (( ! DRY )); then
  ts_version="$(tree-sitter --version 2>/dev/null || true)"
  if ! version_at_least "$ts_version" 0 26 1; then
    fail "tree-sitter-cli >= 0.26.1 requis; vérifier le RPM et le PATH"
  fi
fi

# No curl | sh. Binary/font assets are pinned and SHA-256 checked by this helper.
asset() {
  local name=$1 binary=${2:-}
  if (( ! DRY )) && [[ -n $binary ]] && command -v "$binary" >/dev/null; then
    echo "  déjà disponible: $binary ($(command -v "$binary"))"
    return
  fi
  attempt "asset $name" python3 -B "$HERE/lib/install_asset.py" "$name"
}
if (( SKIP_MANUAL )); then
  SKIPPED+=("outils hors dépôts et polices Nerd Font (--skip-manual)")
else
  if want_tier 1; then
    say "CLI hors dépôts (versions vérifiées dans assets.json)"
    asset lazygit lazygit
  fi
  if want_tier 2; then
    say "Outils de développement hors dépôts"
    asset mise mise
    asset uv uv
    asset lazydocker lazydocker
    # Build on this architecture. Install only if missing; no implicit upgrades.
    for spec in dua-cli:2.44.0:dua diskonaut:0.11.0:diskonaut; do
      IFS=: read -r crate version binary <<<"$spec"
      if (( ! DRY )) && command -v "$binary" >/dev/null; then
        echo "  déjà disponible: $binary"; continue
      fi
      if (( DRY )) || command -v cargo >/dev/null; then
        attempt "cargo $crate" cargo install --locked --version "$version" "$crate"
      else
        fail "$crate (cargo absent)"
      fi
    done
  fi
  if want_tier 3; then
    say "Police Nerd Font utilisateur"
    asset jetbrains-mono
  fi
  if want_tier 4; then
    say "Flatpaks utilisateur (disponibilité ARM64 vérifiée par Flatpak)"
    if (( DRY )) || command -v flatpak >/dev/null; then
      if run flatpak remote-add --if-not-exists --user flathub https://dl.flathub.org/repo/flathub.flatpakrepo; then
        for app in org.localsend.localsend_app md.obsidian.Obsidian org.signal.Signal; do
          if (( ! DRY )) && flatpak info --user --arch=aarch64 "$app" >/dev/null 2>&1; then
            echo "  déjà installé (utilisateur): $app"; continue
          fi
          attempt "flatpak $app" flatpak install -y --user --arch=aarch64 flathub "$app"
        done
      else
        fail "ajout de Flathub utilisateur"
      fi
    else
      fail "flatpak absent"
    fi
  fi
fi

say "Bilan"
if (( ${#SKIPPED[@]} )); then printf '  Ignoré volontairement: %s\n' "${SKIPPED[@]}"; fi
if (( ${#FAILED[@]} )); then
  printf '  ÉCHEC: %s\n' "${FAILED[@]}"
  echo "Installation incomplète. Corriger les erreurs ci-dessus puis relancer." >&2
  exit 1
fi
if (( DRY )); then
  echo "Simulation seulement: aucun paquet, téléchargement ou fichier modifié."
else
  echo "Toutes les opérations sélectionnées ont réussi."
fi
echo "Suite: ./restore.sh --dry-run puis RESTORE.md (NVM, Plasma, Podman)."
