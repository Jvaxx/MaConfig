#!/usr/bin/env bash
# Sauvegarde : ~/.config  ->  ce repo
# Usage: ./sync.sh [--commit]
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
SRC="$HOME"
DST="$HERE/home"
# Entrées `shared:` du MANIFEST : elles repartent dans l'arbre partagé, pas ici.
SHARED="$ROOT/shared/home"
MANIFEST="$HERE/MANIFEST"

[[ -f $MANIFEST ]] || { echo "MANIFEST introuvable"; exit 1; }

copied=0 linked=0 missing=0
while IFS= read -r line; do
  line="${line%%#*}"; line="$(echo "$line" | xargs || true)"
  [[ -z $line ]] && continue

  if [[ $line == shared:* ]]; then
    rel="${line#shared:}"; dst="$SHARED/$rel"; tag="shared"
  else
    rel="$line";           dst="$DST/$rel";    tag="local "
  fi
  src="$SRC/$rel"

  # Déjà un symlink vers le repo (cas de ~/.config/nvim) : rien à recopier,
  # les éditions sont déjà dans l'arbre versionné.
  if [[ -L $src ]] && [[ "$(readlink -f "$src")" == "$(readlink -f "$dst")" ]]; then
    echo "  link [$tag] $rel"
    linked=$((linked+1))
    continue
  fi

  if [[ -d $src ]]; then
    rm -rf "$dst"
    mkdir -p "$(dirname "$dst")"
    # exclut les métadonnées git et les backups horodatés d'omarchy
    rsync -a --exclude '.git/' --exclude '*.bak.*' "$src/" "$dst/"
    echo "  dir  [$tag] $rel"
    copied=$((copied+1))
  elif [[ -f $src ]]; then
    mkdir -p "$(dirname "$dst")"
    cp -p "$src" "$dst"
    echo "  file [$tag] $rel"
    copied=$((copied+1))
  else
    echo "  !!   ABSENT: $rel" >&2
    missing=$((missing+1))
  fi
done < "$MANIFEST"

# Métadonnées utiles à la restauration
{
  echo "omarchy_version=$(omarchy version 2>/dev/null || echo unknown)"
  echo "synced_at=$(date -Iseconds)"
  echo "hostname=$(hostname)"
} > "$HERE/STATE"

# Paquets installés explicitement. Liste de référence pour la restauration
# manuelle (restore.sh n'installe rien) : sans elle, on restaure la config de
# songrec / direnv / voxtype / librepods sans les paquets correspondants.
if command -v pacman >/dev/null 2>&1; then
  {
    echo "# Paquets explicites (pacman -Qqe) — $(date -Iseconds)"
    echo "# Référence uniquement : à réinstaller à la main après restauration."
    pacman -Qqe
  } > "$HERE/packages.txt"
  echo "  list packages.txt ($(pacman -Qqe | wc -l) paquets)"
fi

# Plugins shell installés depuis un dépôt externe : on ne stocke que l'URL
: > "$HERE/external-plugins.txt"
for p in "$SRC"/.config/omarchy/plugins/*/; do
  [[ -d $p/.git ]] || continue
  url="$(git -C "$p" remote get-url origin 2>/dev/null || true)"
  [[ -n $url ]] && echo "$(basename "$p")	$url" >> "$HERE/external-plugins.txt"
done

echo
echo "Sauvegardé: $copied entrée(s), symlinks: $linked, manquant: $missing"

if [[ ${1:-} == --commit ]]; then
  cd "$ROOT"
  git add -A .
  git commit -m "quattro: sync config $(date +%F)" || echo "rien à commiter"
  echo "Pense à: git push"
fi
