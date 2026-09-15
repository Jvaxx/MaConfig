#!/usr/bin/env bash
# Installer les liens dépôt -> $HOME (copies pour les exceptions copy:).
# Aucun paquet installé ni service redémarré.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
YES=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY=1 ;;
    --yes|-y) YES=1 ;;
    *) echo "Usage: $0 [--dry-run] [--yes]" >&2; exit 1 ;;
  esac
done

# Vérifier les sources avant de toucher à $HOME.
while IFS= read -r line || [[ -n $line ]]; do
  entry "$line" || continue
  [[ -e $repo ]] || { echo "Source absente: $repo" >&2; exit 1; }
done < "$HERE/MANIFEST"

if (( ! DRY && ! YES )); then
  read -r -p "Installer les liens/configs vers $HOME (anciens fichiers en *.bak.$STAMP) ? [y/N] " answer
  [[ $answer == y || $answer == Y ]] || exit 0
fi
while IFS= read -r line || [[ -n $line ]]; do
  entry "$line" || continue
  if [[ $mode == copy ]]; then
    copy_entry "$repo" "$HOME/$rel" yes
  else
    link_entry
  fi
done < "$HERE/MANIFEST"

echo "Terminé. Aucun paquet installé, service relancé ou réglage système appliqué."
