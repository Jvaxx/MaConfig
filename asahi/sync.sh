#!/usr/bin/env bash
# Sauvegarde : $HOME  ->  ce repo   (hôte Fedora Asahi Remix / KDE)
# Usage: ./sync.sh [--commit]
#
# Symétrique de restore.sh : les entrées `shared:` repartent dans ../shared/home,
# les autres dans ./home. Une entrée restaurée en --link est déjà un symlink vers
# le repo, on la saute alors au lieu de se copier sur elle-même.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
SRC="$HOME"
DST="$HERE/home"
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

  # Déjà un symlink vers le repo (restore.sh --link) : rien à recopier.
  if [[ -L $src ]] && [[ "$(readlink -f "$src")" == "$(readlink -f "$dst")" ]]; then
    echo "  link [$tag] $rel"
    linked=$((linked+1))
    continue
  fi

  if [[ -d $src ]]; then
    rm -rf "$dst"; mkdir -p "$(dirname "$dst")"
    rsync -a --exclude '.git/' --exclude '*.bak.*' "$src/" "$dst/"
    echo "  dir  [$tag] $rel"; copied=$((copied+1))
  elif [[ -f $src ]]; then
    mkdir -p "$(dirname "$dst")"; cp -p "$src" "$dst"
    echo "  file [$tag] $rel"; copied=$((copied+1))
  else
    echo "  !!   ABSENT: $rel" >&2; missing=$((missing+1))
  fi
done < "$MANIFEST"

{
  echo "distro=$(. /etc/os-release 2>/dev/null && echo "${PRETTY_NAME:-unknown}")"
  echo "kernel=$(uname -r)"
  echo "arch=$(uname -m)"
  echo "desktop=${XDG_CURRENT_DESKTOP:-unknown}"
  echo "nvim=$(nvim --version 2>/dev/null | head -1 || echo absent)"
  echo "synced_at=$(date -Iseconds)"
  echo "hostname=$(hostname)"
} > "$HERE/STATE"

# Liste de référence, pendant du packages.txt de quattro.
if command -v rpm >/dev/null 2>&1; then
  {
    echo "# Paquets installés par l'utilisateur — $(date -Iseconds)"
    echo "# Référence uniquement. La liste voulue est dans packages.dnf."
    # dnf5 (Fedora 41+) a retiré `history userinstalled` ; repoquery le remplace.
    dnf repoquery --qf '%{name}' --userinstalled 2>/dev/null | sort -u \
      || dnf history userinstalled 2>/dev/null | tail -n +2 | sort
  } > "$HERE/packages.installed.txt"
fi

echo
echo "Copié: $copied  symlinks: $linked  manquant: $missing"

if [[ ${1:-} == --commit ]]; then
  cd "$ROOT"
  git add -A .
  git commit -m "asahi: sync config $(date +%F)" || echo "rien à commiter"
  echo "Pense à: git push"
fi
