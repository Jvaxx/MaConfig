#!/usr/bin/env bash
# Vérifier les liens, sauvegarder les exceptions et exporter les inventaires.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
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
while IFS= read -r line || [[ -n $line ]]; do
  entry "$line" || continue
  if [[ $mode == link ]] && ! linked_entry; then
    echo "Lien absent/incorrect: $HOME/$rel -> $repo" >&2
    INVALID=1
  fi
done < "$HERE/MANIFEST"
if (( INVALID )); then
  echo "Comparer les configs locales au dépôt, puis lancer quattro/restore.sh." >&2
  exit 1
fi

while IFS= read -r line || [[ -n $line ]]; do
  entry "$line" || continue
  [[ $mode == copy ]] || continue
  if [[ ! -e $HOME/$rel ]]; then
    echo "Absent (sauvegarde conservée): $rel" >&2
    continue
  fi
  copy_entry "$HOME/$rel" "$repo" no
done < "$HERE/MANIFEST"

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
if command -v pacman >/dev/null 2>&1; then
  {
    echo "# Paquets explicites (pacman -Qqe) — $(date -Iseconds)"
    echo "# Référence uniquement : à réinstaller à la main après restauration."
    pacman -Qqe
  } > "$stage/packages.txt"
fi
: > "$stage/external-plugins.txt"
for p in "$HOME"/.config/omarchy/plugins/*/; do
  [[ -e $p/.git ]] || continue
  url="$(git -C "$p" remote get-url origin)"
  [[ -z $url ]] || printf '%s\t%s\n' "$(basename "$p")" "$url" >> "$stage/external-plugins.txt"
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
