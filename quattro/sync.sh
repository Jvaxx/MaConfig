#!/usr/bin/env bash
# Sauvegarde : ~/.config  ->  ce repo
# Usage: ./sync.sh [--commit]
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$HOME"
DST="$HERE/home"
MANIFEST="$HERE/MANIFEST"

[[ -f $MANIFEST ]] || { echo "MANIFEST introuvable"; exit 1; }

copied=0 missing=0
while IFS= read -r line; do
  line="${line%%#*}"; line="$(echo "$line" | xargs || true)"
  [[ -z $line ]] && continue

  src="$SRC/$line"
  dst="$DST/$line"

  if [[ -d $src ]]; then
    rm -rf "$dst"
    mkdir -p "$(dirname "$dst")"
    # exclut les métadonnées git et les backups horodatés d'omarchy
    rsync -a --exclude '.git/' --exclude '*.bak.*' "$src/" "$dst/"
    echo "  dir  $line"
    copied=$((copied+1))
  elif [[ -f $src ]]; then
    mkdir -p "$(dirname "$dst")"
    cp -p "$src" "$dst"
    echo "  file $line"
    copied=$((copied+1))
  else
    echo "  !!   ABSENT: $line" >&2
    missing=$((missing+1))
  fi
done < "$MANIFEST"

# Métadonnées utiles à la restauration
{
  echo "omarchy_version=$(omarchy version 2>/dev/null || echo unknown)"
  echo "synced_at=$(date -Iseconds)"
  echo "hostname=$(hostname)"
} > "$HERE/STATE"

# Plugins shell installés depuis un dépôt externe : on ne stocke que l'URL
: > "$HERE/external-plugins.txt"
for p in "$SRC"/.config/omarchy/plugins/*/; do
  [[ -d $p/.git ]] || continue
  url="$(git -C "$p" remote get-url origin 2>/dev/null || true)"
  [[ -n $url ]] && echo "$(basename "$p")	$url" >> "$HERE/external-plugins.txt"
done

echo
echo "Sauvegardé: $copied entrée(s), manquant: $missing"

if [[ ${1:-} == --commit ]]; then
  cd "$HERE"
  git add -A .
  git commit -m "quattro: sync config $(date +%F)" || echo "rien à commiter"
  echo "Pense à: git push"
fi
