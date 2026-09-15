#!/usr/bin/env bash
# $HOME -> dépôt. Faire un pull puis restore avant le premier sync !
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

while IFS= read -r line || [[ -n $line ]]; do
  entry "$line" || continue
  src="$HOME/$rel"
  if [[ ! -e $src ]]; then
    echo "  absent (sauvegarde conservée): $rel" >&2
    continue
  fi
  copy_entry "$src" "$repo" no
done < "$HERE/MANIFEST"

if (( DRY )); then
  echo "  exporter: Brewfile et STATE (si Homebrew/macOS disponibles)"
  exit 0
fi
if command -v brew >/dev/null 2>&1; then
  # Dump dans un fichier temporaire : conserver le dernier inventaire si échec.
  tmp="$(mktemp -d "$HERE/.maconfig-stage-XXXXXX")"
  trap 'rm -rf "$tmp"' EXIT
  HOMEBREW_NO_AUTO_UPDATE=1 brew bundle dump --file="$tmp/Brewfile" --force --no-vscode
  mv "$tmp/Brewfile" "$HERE/Brewfile"
  rmdir "$tmp"
  trap - EXIT
else
  echo "Homebrew absent : Brewfile conservé." >&2
fi
{
  echo "synced_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "hostname=$(hostname)"
  echo "arch=$(uname -m)"
  if command -v sw_vers >/dev/null 2>&1; then
    echo "macos_version=$(sw_vers -productVersion)"
  fi
} > "$HERE/STATE"

if (( COMMIT )); then
  git -C "$ROOT" add -A -- macos shared/home
  if ! git -C "$ROOT" diff --cached --quiet -- macos shared/home; then
    git -C "$ROOT" commit --only -m "macos: sync config $(date +%F)" -- macos shared/home
  fi
  echo "Pense à git push."
fi
