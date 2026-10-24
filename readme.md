Mes sauvegardes de config.

```
MaConfig/
├── shared/home/   configs identiques sur toutes les machines
├── quattro/       Arch + Hyprland + Omarchy   (FIXEJVZ, x86_64)
├── m3pro/         Arch ARM + Omarchy, MacBook Pro M3 Pro (MBP14OmarchyDev, aarch64)
└── macos/         macOS (Zsh, yabai/skhd, Ghostty, Karabiner, Homebrew)
```

Chaque hôte a son `MANIFEST`, son `restore.sh` et son `sync.sh`. Une entrée de
MANIFEST vient soit de l'arbre local `home/`, soit de `../shared/home` quand
elle est préfixée `shared:` :

```
.config/foot/foot.ini          -> quattro/home/.config/foot/foot.ini
shared:.config/tmux/tmux.conf  -> shared/home/.config/tmux/tmux.conf
```

**Règle de répartition** : ce qui référence Hyprland ou le système de thèmes
Omarchy (`~/.local/state/omarchy/current/…`) reste local à chaque hôte Omarchy
(`quattro/`, `m3pro/`). Le reste
peut aller dans `shared/` — nvim, tmux, starship, git, les règles Compose et le
`CLAUDE.md` de Claude Code. Les layouts XKB restent locaux à `quattro/`.
`m3pro/` part de la config de Quattro, en copies adaptées au portable (clavier
Mac, encoche, autre version d'Omarchy) : voir `m3pro/RESTORE.md`.

Mise en route d'une machine : `quattro/RESTORE.md`, `m3pro/RESTORE.md` ou
`macos/RESTORE.md`.
Sur macOS, seuls Neovim, tmux et Starship sont partagés ; Git et Zsh restent
locaux (les helpers Git Linux ne sont pas portables).
`restore.sh` installe des liens vers le dépôt ; `sync.sh` vérifie les liens et
exporte les inventaires. Les entrées `copy:` (Karabiner sur macOS ; shell.json,
btop et les presets de workspaces sur Quattro) gardent le fonctionnement par copie.
