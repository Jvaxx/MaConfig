#!/usr/bin/env bash
# Installer les liens et restaurer les exceptions, avec sauvegarde préalable.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
YES=0; RELOAD=1
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY=1 ;;
    --yes|-y) YES=1 ;;
    --no-reload) RELOAD=0 ;;
    *) echo "Usage: $0 [--dry-run] [--yes] [--no-reload]" >&2; exit 1 ;;
  esac
done

# Vérifier toutes les sources avant de toucher HOME.
INVALID=0
while IFS= read -r line || [[ -n $line ]]; do
  entry "$line" || continue
  if [[ ! -e $repo ]]; then
    echo "Source absente: $repo" >&2
    INVALID=1
  fi
done < "$HERE/MANIFEST"
(( ! INVALID )) || exit 1

if (( ! DRY && ! YES )); then
  read -rp "Installer les liens (existants sauvegardés en *.bak.$STAMP) ? [y/N] " answer
  [[ $answer =~ ^[yY]$ ]] || exit 0
fi
while IFS= read -r line || [[ -n $line ]]; do
  entry "$line" || continue
  if [[ $mode == link ]]; then
    link_entry
  elif [[ -f $repo && -f $HOME/$rel ]] && cmp -s "$repo" "$HOME/$rel"; then
    echo "  identique: $rel"
  else
    copy_entry "$repo" "$HOME/$rel" yes
  fi
done < "$HERE/MANIFEST"

if [[ -s $HERE/external-plugins.txt ]]; then
  while IFS=$'\t' read -r id url; do
    [[ -n $id ]] || continue
    target="$HOME/.config/omarchy/plugins/$id"
    [[ ! -e $target ]] || continue
    if (( DRY )); then
      echo "  cloner: $id <- $url"
    else
      git clone --depth 1 "$url" "$target"
    fi
  done < "$HERE/external-plugins.txt"
fi
(( ! DRY && RELOAD )) || exit 0

gtk-update-icon-cache "$HOME/.local/share/icons/hicolor" >/dev/null 2>&1 || true
update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true
systemctl --user daemon-reload
hyprctl reload
hyprctl configerrors
omarchy restart shell
omarchy restart terminal
echo "Terminé. Vérifie 'hyprctl configerrors' ci-dessus."
