#!/usr/bin/env bash
# Restauration : ce repo  ->  ~/.config
# Usage: ./restore.sh [--dry-run] [--yes]
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
DEST="$HOME"
SRC="$HERE/home"
# Arbre partagé avec les autres hôtes (voir ../shared). Les entrées du MANIFEST
# préfixées `shared:` en viennent au lieu de ./home.
SHARED="$ROOT/shared/home"
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
[[ -d $SHARED ]] || { echo "Arbre partagé introuvable: $SHARED"; exit 1; }

echo "Restauration depuis $SRC (+ $SHARED) vers $DEST"
[[ -f $HERE/STATE ]] && sed 's/^/  /' "$HERE/STATE"
echo

if (( ! DRY && ! YES )); then
  read -rp "Les fichiers existants seront sauvegardés en *.bak.$STAMP. Continuer ? [y/N] " r
  [[ $r =~ ^[yY]$ ]] || exit 0
fi

while IFS= read -r line; do
  line="${line%%#*}"; line="$(echo "$line" | xargs || true)"
  [[ -z $line ]] && continue

  if [[ $line == shared:* ]]; then
    rel="${line#shared:}"; src="$SHARED/$rel"; tag="shared"
  else
    rel="$line";           src="$SRC/$rel";    tag="local "
  fi
  dst="$DEST/$rel"
  [[ -e $src ]] || continue

  # Déjà un symlink vers la source (cas de ~/.config/nvim) : le remplacer par une
  # copie casserait le lien et ferait diverger $HOME du dépôt à la prochaine
  # édition. On le laisse tel quel.
  if [[ -L $dst ]] && [[ "$(readlink -f "$dst")" == "$(readlink -f "$src")" ]]; then
    echo "  link     [$tag] $rel"
    continue
  fi

  if (( DRY )); then echo "  would restore [$tag] $rel"; continue; fi

  # -e est faux pour un symlink cassé, d'où le -L en complément.
  [[ -e $dst || -L $dst ]] && mv "$dst" "$dst.bak.$STAMP"
  mkdir -p "$(dirname "$dst")"
  cp -a "$src" "$dst"
  echo "  restored [$tag] $rel"
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
# Lanceurs et icônes des web apps perso : les fichiers copiés ne sont visibles
# dans le launcher qu'après régénération des caches.
gtk-update-icon-cache "$DEST/.local/share/icons/hicolor" >/dev/null 2>&1 || true
update-desktop-database "$DEST/.local/share/applications" >/dev/null 2>&1 || true
hyprctl reload            >/dev/null 2>&1 || true
hyprctl configerrors      || true
omarchy restart shell     >/dev/null 2>&1 || true
omarchy restart terminal  >/dev/null 2>&1 || true
echo "Terminé. Vérifie 'hyprctl configerrors' ci-dessus."
