#!/usr/bin/env bash
# Restauration : ce repo  ->  $HOME   (hôte Fedora Asahi Remix / KDE)
# Usage: ./restore.sh [--dry-run] [--yes] [--link]
#
# --link : symlink au lieu de copier (les éditions dans $HOME reviennent dans le
#          repo toutes seules). C'est déjà ainsi que ~/.config/nvim est géré sur
#          la machine Arch.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
DEST="$HOME"
SRC="$HERE/home"
SHARED="$ROOT/shared/home"
MANIFEST="$HERE/MANIFEST"
STAMP="$(date +%s)"

DRY=0; YES=0; LINK=0
for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    --yes|-y)  YES=1 ;;
    --link)    LINK=1 ;;
    *) echo "option inconnue: $a"; exit 1 ;;
  esac
done

[[ -d $SHARED ]] || { echo "Arbre partagé introuvable: $SHARED"; exit 1; }

echo "Restauration vers $DEST"
echo "  local   : $SRC"
echo "  partagé : $SHARED"
(( LINK )) && echo "  mode    : symlink" || echo "  mode    : copie"
echo

if (( ! DRY && ! YES )); then
  read -rp "Les fichiers existants seront sauvegardés en *.bak.$STAMP. Continuer ? [y/N] " r
  [[ $r =~ ^[yY]$ ]] || exit 0
fi

n_local=0; n_shared=0; n_missing=0; n_link=0

while IFS= read -r line; do
  line="${line%%#*}"; line="$(echo "$line" | xargs || true)"
  [[ -z $line ]] && continue

  # Préfixe shared: -> l'entrée vient de ../shared/home
  if [[ $line == shared:* ]]; then
    rel="${line#shared:}"; src="$SHARED/$rel"; tag="shared"
  else
    rel="$line";           src="$SRC/$rel";    tag="local "
  fi
  dst="$DEST/$rel"

  if [[ ! -e $src ]]; then
    echo "  !! ABSENT ($tag) $rel" >&2
    n_missing=$((n_missing+1))
    continue
  fi

  # Déjà un symlink vers la source (mode --link déjà appliqué, ou lien posé à la
  # main) : le remplacer par une copie ferait diverger $HOME du dépôt.
  if [[ -L $dst ]] && [[ "$(readlink -f "$dst")" == "$(readlink -f "$src")" ]]; then
    echo "  link     [$tag] $rel"
    n_link=$((n_link+1))
    continue
  fi

  if (( DRY )); then
    echo "  would restore [$tag] $rel"
  else
    # -e est faux pour un symlink cassé, d'où le -L en complément.
    if [[ -e $dst || -L $dst ]]; then mv "$dst" "$dst.bak.$STAMP"; fi
    mkdir -p "$(dirname "$dst")"
    if (( LINK )); then ln -sfn "$src" "$dst"; else cp -a "$src" "$dst"; fi
    echo "  restored [$tag] $rel"
  fi

  [[ $tag == shared ]] && n_shared=$((n_shared+1)) || n_local=$((n_local+1))
done < "$MANIFEST"

echo
echo "local: $n_local  partagé: $n_shared  symlinks intacts: $n_link  manquant: $n_missing"
(( DRY )) && exit 0

echo
echo "Étapes qui ne peuvent pas être scriptées ici — voir RESTORE.md :"
echo "  1. Layout clavier frmac dans Plasma (Réglages > Clavier > Dispositions)"
echo "  2. Premier lancement de nvim : vim.pack clone les plugins, puis :checkhealth"
echo "  3. foot en terminal par défaut de Plasma"
