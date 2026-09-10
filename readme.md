Mes sauvegardes de config.

```
MaConfig/
├── shared/home/   configs identiques sur toutes les machines
├── quattro/       Arch + Hyprland + Omarchy   (FIXEJVZ, x86_64)
├── asahi/         Fedora Asahi Remix + KDE    (MacBook Pro M3 Pro, aarch64)
└── macos/         macOS — historique (yabai, skhd, ghostty)
```

Chaque hôte a son `MANIFEST`, son `restore.sh` et son `sync.sh`. Une entrée de
MANIFEST vient soit de l'arbre local `home/`, soit de `../shared/home` quand
elle est préfixée `shared:` :

```
.config/foot/foot.ini          -> quattro/home/.config/foot/foot.ini
shared:.config/tmux/tmux.conf  -> shared/home/.config/tmux/tmux.conf
```

**Règle de répartition** : ce qui référence Hyprland ou le système de thèmes
Omarchy (`~/.local/state/omarchy/current/…`) reste local à `quattro/`. Le reste
va dans `shared/` — nvim, tmux, starship, git, les layouts XKB, les fragments
shell et les règles Compose perso.

Mise en route d'une machine : `quattro/RESTORE.md` ou `asahi/RESTORE.md`.
Ce qui a été élagué au portage vers le Mac : `asahi/DROPPED.md`.
