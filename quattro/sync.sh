#!/usr/bin/env bash
# Vérifier les liens, sauvegarder les exceptions, signaler les configs non
# suivies et exporter les inventaires.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
OMARCHY_PATH="${OMARCHY_PATH:-/usr/share/omarchy}"
COMMIT=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY=1 ;;
    --commit) COMMIT=1 ;;
    *) echo "Usage: $0 [--dry-run] [--commit]" >&2; exit 1 ;;
  esac
done

# Ne jamais remplacer une config du dépôt par une copie locale divergente.
INVALID=0
tracked=()
while IFS= read -r line || [[ -n $line ]]; do
  entry "$line" || continue
  tracked+=("$rel")
  if [[ $mode == link ]] && ! linked_entry; then
    echo "Lien absent/incorrect: $HOME/$rel -> $repo" >&2
    INVALID=1
  fi
done < "$HERE/MANIFEST"
if (( INVALID )); then
  echo "Comparer les configs locales au dépôt, puis lancer quattro/restore.sh." >&2
  exit 1
fi

ignored=()
if [[ -f $HERE/UNTRACKED ]]; then
  while IFS= read -r line || [[ -n $line ]]; do
    entry "$line" || continue
    ignored+=("$rel")
  done < "$HERE/UNTRACKED"
fi

# Suivi par le MANIFEST (entrée ou sous-chemin), ou écarté par UNTRACKED (motifs glob).
known() {
  local p
  for p in "${tracked[@]}"; do
    [[ $1 == "$p" || $1 == "$p"/* ]] && return 0
  done
  for p in "${ignored[@]}"; do
    # shellcheck disable=SC2053 # $p est un motif glob
    [[ $1 == $p || $1 == $p/* ]] && return 0
  done
  return 1
}

# Repère ce qui a été personnalisé sans être sauvegardé : défauts Omarchy
# modifiés, puis fichiers perso dans les dossiers de scripts/unités/fragments.
# Les liens sont ignorés : ce sont les nôtres ou ceux d'autres installateurs.
audit() {
  local f rel dir found=()
  if [[ -d $OMARCHY_PATH/config ]]; then
    while IFS= read -r -d '' f; do
      rel=".config/${f#"$OMARCHY_PATH/config/"}"
      if [[ -e $HOME/$rel ]] && ! cmp -s "$f" "$HOME/$rel" && ! known "$rel"; then
        found+=("$rel (diffère du défaut Omarchy)")
      fi
    done < <(find "$OMARCHY_PATH/config" -type f -print0 2>/dev/null)
  fi
  for dir in .local/bin .config/systemd/user .config/hypr \
      .config/wireplumber/wireplumber.conf.d .config/omarchy/hooks .config/omarchy/extensions; do
    [[ -d $HOME/$dir ]] || continue
    while IFS= read -r -d '' f; do
      rel="${f#"$HOME/"}"
      case "$rel" in *.bak.*|*/__pycache__/*) continue ;; esac
      # Un défaut Omarchy : déjà traité ci-dessus.
      [[ -e $OMARCHY_PATH/config/${rel#.config/} ]] && continue
      if ! known "$rel"; then
        found+=("$rel")
      fi
    done < <(find "$HOME/$dir" -type f -print0 2>/dev/null)
  done
  if (( ${#found[@]} )); then
    echo "Non suivis (ajouter au MANIFEST, ou à UNTRACKED pour les écarter) :"
    printf '  %s\n' "${found[@]}" | sort
  fi
}

while IFS= read -r line || [[ -n $line ]]; do
  entry "$line" || continue
  [[ $mode == copy ]] || continue
  if [[ ! -e $HOME/$rel ]]; then
    echo "Absent (sauvegarde conservée): $rel" >&2
    continue
  fi
  copy_entry "$HOME/$rel" "$repo" no
done < "$HERE/MANIFEST"
audit

if (( DRY )); then
  echo "  exporter: STATE, packages.txt et external-plugins.txt"
  exit 0
fi
stage="$(mktemp -d "$HERE/.maconfig-stage-XXXXXX")"
trap 'rm -rf "$stage"' EXIT
{
  echo "omarchy_version=$(omarchy version 2>/dev/null || echo unknown)"
  echo "synced_at=$(date -Iseconds)"
  echo "hostname=$(hostname)"
} > "$stage/STATE"
# Pas de date ici : packages.txt ne change que si la liste change (STATE date le sync).
if command -v pacman >/dev/null 2>&1; then
  {
    echo "# Paquets explicites (pacman -Qqe) au dernier sync, voir STATE."
    echo "# Référence uniquement : à réinstaller à la main après restauration."
    pacman -Qqe
  } > "$stage/packages.txt"
fi
: > "$stage/external-plugins.txt"
for p in "$HOME"/.config/omarchy/plugins/*/; do
  [[ -e $p/.git ]] || continue
  url="$(git -C "$p" remote get-url origin 2>/dev/null || true)"
  if [[ -n $url ]]; then
    printf '%s\t%s\n' "$(basename "$p")" "$url" >> "$stage/external-plugins.txt"
  else
    echo "Plugin git sans remote origin (non réinstallable): $(basename "$p")" >&2
  fi
done
for file in "$stage"/*; do mv "$file" "$HERE/"; done
rmdir "$stage"
trap - EXIT

if (( COMMIT )); then
  git -C "$ROOT" add -A -- quattro shared/home
  if ! git -C "$ROOT" diff --cached --quiet -- quattro shared/home; then
    git -C "$ROOT" commit --only -m "quattro: sync config $(date +%F)" -- quattro shared/home
  fi
  echo "Pense à git push."
fi
