#!/usr/bin/env bash
# Restauration : ce repo  ->  ~/.config
# Usage: ./restore.sh [--dry-run] [--yes]
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="$HOME"
SRC="$HERE/home"
MANIFEST="$HERE/MANIFEST"
STAMP="$(date +%s)"

DRY=0; YES=0
for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    --yes|-y)  YES=1 ;;
    *) echo "option inconnue: $a"; exit 1 ;;
  esac
done

[[ -d $SRC ]] || { echo "Aucune sauvegarde dans $SRC — lance sync.sh d'abord."; exit 1; }

echo "Restauration depuis $SRC vers $DEST"
[[ -f $HERE/STATE ]] && sed 's/^/  /' "$HERE/STATE"
echo

if (( ! DRY && ! YES )); then
  read -rp "Les fichiers existants seront sauvegardés en *.bak.$STAMP. Continuer ? [y/N] " r
  [[ $r =~ ^[yY]$ ]] || exit 0
fi

while IFS= read -r line; do
  line="${line%%#*}"; line="$(echo "$line" | xargs || true)"
  [[ -z $line ]] && continue

  src="$SRC/$line"
  dst="$DEST/$line"
  [[ -e $src ]] || continue

  if (( DRY )); then echo "  would restore $line"; continue; fi

  [[ -e $dst ]] && mv "$dst" "$dst.bak.$STAMP"
  mkdir -p "$(dirname "$dst")"
  cp -a "$src" "$dst"
  echo "  restored $line"
done < "$MANIFEST"

(( DRY )) && exit 0

# Réinstaller les plugins shell externes
if [[ -s $HERE/external-plugins.txt ]]; then
  echo
  echo "Plugins externes à réinstaller :"
  while IFS=$'\t' read -r id url; do
    [[ -z ${id:-} ]] && continue
    target="$DEST/.config/omarchy/plugins/$id"
    if [[ -d $target ]]; then
      echo "  déjà présent: $id"
    else
      echo "  clone $id <- $url"
      git clone --depth 1 "$url" "$target"
    fi
  done < "$HERE/external-plugins.txt"
fi

echo
echo "Application des changements..."
hyprctl reload            >/dev/null 2>&1 || true
hyprctl configerrors      || true
omarchy restart shell     >/dev/null 2>&1 || true
omarchy restart terminal  >/dev/null 2>&1 || true
echo "Terminé. Vérifie 'hyprctl configerrors' ci-dessus."
