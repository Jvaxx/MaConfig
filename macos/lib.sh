#!/usr/bin/env bash
# Helpers communs, compatibles avec /bin/bash 3.2 et rsync de macOS.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S).$$"
DRY=0

# Lit une entrée sans casser les espaces (Library/Application Support, etc.).
entry() {
  local line="${1%%#*}"
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"
  [[ -n $line ]] || return 1
  mode=link
  if [[ $line == copy:* ]]; then
    mode=copy
    line="${line#copy:}"
  fi
  rel="${line#shared:}"
  [[ -n $rel ]] || { echo "Chemin vide" >&2; exit 1; }
  case "/$rel/" in
    *'/../'*|*'/./'*|*'//'*) echo "Chemin invalide: $line" >&2; exit 1 ;;
  esac
  if [[ $line == shared:* ]]; then
    repo="$ROOT/shared/home/$rel"
  else
    repo="$HERE/home/$rel"
  fi
}

# Seuls les vrais liens symboliques vers la source sont considérés installés.
linked_entry() {
  [[ -L $HOME/$rel && -e $HOME/$rel && $repo -ef $HOME/$rel ]]
}

link_entry() {
  local dst="$HOME/$rel"
  if linked_entry; then
    echo "  déjà lié: $rel"
    return
  fi
  if (( DRY )); then
    echo "  lier (sauvegarde si existant): $dst -> $repo"
    return
  fi
  mkdir -p "$(dirname "$dst")"
  if [[ -e $dst || -L $dst ]]; then
    mv "$dst" "$dst.bak.$STAMP"
  fi
  if ! ln -s "$repo" "$dst"; then
    if [[ -e $dst.bak.$STAMP || -L $dst.bak.$STAMP ]]; then
      mv "$dst.bak.$STAMP" "$dst"
    fi
    return 1
  fi
  echo "  lié: $rel"
}

# Staging avant remplacement : un échec de copie ne détruit pas l'existant.
# Les liens à la racine sont déréférencés ; les liens internes sont conservés.
copy_entry() {
  local src="$1" dst="$2" backup="$3" stage
  if [[ -e $dst && $src -ef $dst ]]; then
    echo "  déjà lié: $rel"
    return
  fi
  if (( DRY )); then
    echo "  copier: $src -> $dst"
    return
  fi
  mkdir -p "$(dirname "$dst")"
  stage="$(mktemp -d "$(dirname "$dst")/.maconfig-stage-XXXXXX")"
  if [[ -d $src ]]; then
    mkdir "$stage/value"
    if ! rsync -a --exclude '.git' --exclude '.DS_Store' --exclude '*.bak.*' \
        --exclude '.maconfig-stage-*' "$src/" "$stage/value/"; then
      rm -rf "$stage"; return 1
    fi
  else
    if ! cp -pL "$src" "$stage/value"; then
      rm -rf "$stage"; return 1
    fi
  fi
  if [[ -e $dst || -L $dst ]]; then
    if [[ $backup == yes ]]; then
      mv "$dst" "$dst.bak.$STAMP"
    else
      # Supprime le lien lui-même, jamais sa cible.
      rm -rf "$dst"
    fi
  fi
  mv "$stage/value" "$dst"
  rmdir "$stage"
  echo "  copié: $rel"
}
