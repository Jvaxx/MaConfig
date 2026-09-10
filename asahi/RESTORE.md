# Mise en route — MacBook Pro M3 Pro / Fedora Asahi Remix / KDE Plasma

Portage de la config `quattro` (Arch + Hyprland + Omarchy) vers cette machine.
Ce qui a été élagué et pourquoi : **[DROPPED.md](DROPPED.md)**.

## Contexte matériel à garder en tête

Asahi sur M3 est encore jeune : **pas d'accélération 3D** (tout passe par
llvmpipe, en CPU), pas de veille, HDMI désactivé. Deux conséquences directes
sur cette config :

- le terminal est **foot** (rendu CPU) et non kitty/alacritty/ghostty, qui
  exigent tous OpenGL ;
- rien de lourd en GPU n'est installé (cf. DROPPED.md §5).

---

## Ordre des opérations

```bash
git clone <ton-remote> ~/Documents/MaConfig
cd ~/Documents/MaConfig/asahi

./bootstrap.sh --dry-run     # 1. relire ce qui va être installé
./bootstrap.sh               # 2. paquets (~15 min, demande sudo)
./restore.sh                 # 3. fichiers de config
exec bash -l                 # 4. recharger le shell
```

Puis les deux étapes manuelles ci-dessous, qui ne peuvent pas être scriptées.

### Options utiles

```bash
./bootstrap.sh --tier 1 --tier 2   # seulement CLI + toolchains
./bootstrap.sh --no-copr           # sauter starship/lazygit/nerd-fonts
./bootstrap.sh --skip-manual       # sauter nvim/mise/uv/cargo/flatpak
./restore.sh --link                # symlinks vers le repo au lieu de copies
./restore.sh --dry-run
```

`--link` est le mode recommandé si tu comptes éditer la config depuis cette
machine : les modifications atterrissent directement dans le dépôt, et
`./sync.sh` n'a plus rien à recopier. C'est déjà comme ça que `~/.config/nvim`
fonctionne sur la machine Arch.

---

## Clavier — rien à faire

Pas de layout XKB à installer sur cette machine. `frmac` et `qwertyansi` ne
sont présents que sur quattro, où ils servent à faire imiter le comportement du
Mac à un clavier PC. Sur le Mac, ce comportement est celui par défaut : les
réglages clavier Plasma sortis de la boîte sont déjà la cible.

Seule chose à vérifier, les séquences Compose. `~/.XCompose` est lu par
libxkbcommon au démarrage de chaque application, donc se déconnecter/reconnecter
après `restore.sh`, puis tester :

| Frappe | Résultat attendu | Vient de |
|---|---|---|
| `Compose` `Espace` `n` | `Jvaxx` | `xcompose/personal` |
| `Compose` `m` `s` | 😄 | `xcompose/emoji` |
| `Compose` `Espace` `Espace` | — (tiret cadratin) | `xcompose/emoji` |

Si une touche Compose n'est pas assignée sur le clavier du MacBook :
*Réglages > Clavier > Dispositions > Touches supplémentaires > Position de la
touche Compose*.

## Étape manuelle 1 — premier lancement de Neovim

`bootstrap.sh` a installé la tarball aarch64 officielle dans `~/.local/nvim`,
avec un symlink dans `~/.local/bin/nvim`. Vérifier :

```bash
nvim --version | head -1     # doit afficher 0.12.x, pas 0.11.x
```

Si c'est 0.11.x, c'est le RPM Fedora qui prend la main dans le `PATH` :
`sudo dnf remove neovim`, ou repositionner `~/.local/bin` devant `/usr/bin`.

Au premier lancement, `vim.pack` clone les ~25 dépôts listés dans `init.lua`
(compte une minute). Ensuite :

```vim
:checkhealth
```

Points à surveiller, propres à l'aarch64 :

- **mason** télécharge des binaires précompilés. `lua-language-server`,
  `rust-analyzer` et `ruff` ont des builds `linux-arm64` ; `clangd`, `gopls` et
  `pyright` sont couverts par les paquets système installés par `bootstrap.sh`
  (`clang-tools-extra`, `gopls`, `nodejs`). Si mason échoue sur l'un d'eux, le
  serveur système prend le relais.
- **nvim-treesitter** compile ses parsers avec le compilateur local — `gcc` est
  installé, ça passe, mais la première compilation est lente sur CPU.
- **telescope-fzf-native** a besoin de `make` (installé).

## Étape manuelle 2 — Plasma

```bash
# foot comme terminal par défaut
kwriteconfig6 --file kdeglobals --group General --key TerminalApplication foot
```

Police : *Réglages > Apparence > Polices > Monospace* → **JetBrainsMono Nerd Font**
(installée depuis le COPR `maveonair/jetbrains-mono-nerd-fonts`). Sans elle,
starship, eza `--icons` et les icônes de diagnostic nvim s'affichent en tofu.

Vérifier :
```bash
fc-list | grep -i "JetBrainsMono Nerd" | head -3
```

Raccourcis clavier : les binds Hyprland n'ont **pas** été portés
(cf. DROPPED.md §8). À recréer à la main dans *Réglages > Raccourcis* selon
l'usage réel — la disposition de Plasma étant flottante par défaut, la plupart
des binds de tiling n'auraient de toute façon pas de sens tels quels.

---

## Vérification finale

```bash
# Shell : les alias partagés sont chargés ?
type ls cd g n | head

# Prompt
starship --version && echo $STARSHIP_SHELL

# Terminal (le lancer depuis Plasma, pas depuis un autre terminal)
foot --version

# tmux : le prefix est C-Space
tmux new -s test

# git : identité et helper gh
git config --get user.email        # jeanvaleryze@gmail.com
gh auth status
```

---

## Entretien

```bash
./sync.sh            # $HOME -> repo (respecte les symlinks de --link)
./sync.sh --commit   # + git commit à la racine de MaConfig
```

`sync.sh` renvoie les entrées `shared:` dans `../shared/home` et les autres dans
`./home`. Une modification faite ici sur `tmux.conf`, `starship.toml`,
`git/config`, les layouts XKB ou la config nvim **profite donc aussi à la
machine Arch** au prochain `quattro/restore.sh`.

Il écrit aussi `STATE` (distro, noyau, arch, version de nvim) et
`packages.installed.txt` (pendant du `packages.txt` de quattro).

## Structure du dépôt

```
MaConfig/
├── shared/home/        configs identiques sur les deux machines
│   └── .config/{nvim,tmux,git,shell,xcompose,xkb}, starship.toml
├── quattro/            hôte Arch + Hyprland + Omarchy
├── asahi/              hôte Fedora + KDE  (ce dossier)
└── macos/              macOS, historique (yabai/skhd/ghostty)
```

Règle de répartition : **tout ce qui référence Hyprland ou le système de thèmes
Omarchy (`~/.local/state/omarchy/current/…`) reste local à `quattro/`**. Le
reste va dans `shared/`. C'est ce qui explique que `foot.ini` et `btop.conf`
soient dupliqués alors que `tmux.conf` ne l'est pas.
