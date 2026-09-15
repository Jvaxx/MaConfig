# Configuration macOS

Voir [RESTORE.md](RESTORE.md) pour sauvegarder/restaurer la machine,
réinstaller les paquets et activer les configurations.

- `MANIFEST` : liste explicite des fichiers suivis.
- `home/` : Zsh, Git, Ghostty, yabai/skhd, Karabiner.
- `../shared/home/` : Neovim, Starship, tmux.
- `sync.sh` / `restore.sh` : mêmes directions que Quattro, avec `--dry-run`.
- `Brewfile` / `STATE` : inventaire Homebrew et date/version au dernier sync.
- `defaults.sh` : quelques préférences système, application séparée.
- `old/` : archives non restaurées.
