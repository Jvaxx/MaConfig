#!/usr/bin/env bash
# Réglages explicites des anciennes notes, pas un export global des préférences.
# Application séparée et volontaire : ./defaults.sh [--dry-run]
set -euo pipefail
DRY=0
case "${1:-}" in
  --dry-run) DRY=1 ;;
  '') ;;
  *) echo "Usage: $0 [--dry-run]" >&2; exit 1 ;;
esac
[[ $# -le 1 ]] || exit 1
apply() {
  if (( DRY )); then printf '%q ' defaults write "$@"; printf '\n';
  else defaults write "$@"; fi
}
apply com.apple.dock autohide-delay -float 0
apply com.apple.dock autohide-time-modifier -float 0
apply NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false
apply NSGlobalDomain QLPanelAnimationDuration -float 0
apply com.apple.dock launchanim -bool false
apply com.apple.dock expose-animation-duration -float 0
apply NSGlobalDomain KeyRepeat -int 1
apply NSGlobalDomain InitialKeyRepeat -int 10
apply NSGlobalDomain ApplePressAndHoldEnabled -bool false
echo 'Réouvrir la session pour appliquer. Aucun service relancé.'
