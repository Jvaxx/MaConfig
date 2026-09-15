# Configuration macOS

Voir [RESTORE.md](RESTORE.md) pour sauvegarder/restaurer la machine,
réinstaller les paquets et activer les configurations.

- `MANIFEST` : chemins liés par défaut ; `shared:` pour les configs partagées,
  `copy:` pour les exceptions gérées par copie (Karabiner).
- `home/` : Zsh, Git, Ghostty, yabai/skhd, Karabiner.
- `../shared/home/` : Neovim, Starship, tmux.
- `restore.sh` : installe les liens vers le dépôt, sauvegarde les anciens fichiers.
- `sync.sh` : valide les liens, importe seulement les exceptions et exporte les
  inventaires ; `--commit` optionnel. Les deux scripts acceptent `--dry-run`.
- Les edits locaux et changements Git affectent directement les configs liées.
  Garder le dépôt à un emplacement stable et relire les changements avant commit.
- `Brewfile` / `STATE` : inventaire Homebrew et date/version au dernier sync.
- `defaults.sh` : quelques préférences système, application séparée.
- `old/` : archives non restaurées.
