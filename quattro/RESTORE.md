# Restauration de ma config Omarchy Quattro

Sauvegarde des customisations faites sur **Omarchy 4.x (Quattro)**.
Seuls les fichiers qui **diffèrent des défauts** (`/usr/share/omarchy/config/`,
`/usr/share/omarchy/default/`) sont ici, plus les fichiers 100 % perso.

## Restauration rapide

```bash
cd ~/Documents/MaConfig/quattro
./restore.sh --dry-run   # voir ce qui serait écrit
./restore.sh             # restaurer (sauvegarde l'existant en *.bak.<timestamp>)
```

`restore.sh` recopie l'arbre `home/` dans `$HOME`, reclone les plugins shell
externes listés dans `external-plugins.txt`, puis relance Hyprland, le shell
Omarchy et les terminaux.

## Sauvegarde (après une modif)

```bash
cd ~/Documents/MaConfig/quattro
./sync.sh            # ~/ -> repo
./sync.sh --commit   # + commit git
git push
```

Pour ajouter/retirer un fichier suivi : éditer `MANIFEST` (chemins relatifs à `$HOME`).

## Structure

| Chemin | Rôle |
|---|---|
| `MANIFEST` | liste des fichiers suivis |
| `home/` | copie fidèle des fichiers, arborescence `$HOME` |
| `sync.sh` / `restore.sh` | backup / restauration |
| `STATE` | version Omarchy + date du dernier sync |
| `external-plugins.txt` | plugins shell clonés depuis GitHub (`id<TAB>url`) |

---

# Ce qui est customisé, et pourquoi

Cette section sert de filet de sécurité si un jour le format change et que les
fichiers ne sont plus recopiables tels quels. Les fichiers eux-mêmes sont
abondamment commentés — les lire reste la meilleure source.

## 1. Clavier — le socle de tout le reste

Clavier **MAD68** : 65 %, QWERTY ANSI physique, sans rangée F, sans touche
`<LSGT>`, piloté en **français (Macintosh)**.

- **`~/.config/xkb/symbols/frmac` et `qwertyansi`** : layouts XKB maison.
  Sans eux, `kb_layout = "frmac,qwertyansi"` ne compile pas et Hyprland
  retombe sur `us`.
- **`~/.config/hypr/input.lua`** :
  - `kb_layout = "frmac,qwertyansi"`, `kb_variant = "ansi,ansi"`
  - `kb_options = "caps:escape_shifted_capslock,altwin:swap_lalt_lwin"`
  - `repeat_rate = 60`, `repeat_delay = 170`
  - **`frmac` doit rester à l'index 0** : `omarchy-system-lock` fait
    `hyprctl switchxkblayout all 0`, et Hyprland résout les keybinds sur l'index 0.
  - **Ne jamais ajouter `grp:alts_toggle`** : ça tue AltGr (donc `@ # \` ~ € {} [] \ |`).
- Vérifier une modif : 
  `xkbcli compile-keymap --layout frmac,qwertyansi --variant ansi,ansi --options caps:escape_shifted_capslock,altwin:swap_lalt_lwin`

**Conséquence sur les keybinds** : `altwin:swap_lalt_lwin` fait mentir les noms
de modificateurs. Un bind écrit `CTRL + ALT` est physiquement Ctrl + Win.

## 2. Keybindings — `~/.config/hypr/bindings.lua`

| Bind | Action | Note |
|---|---|---|
| `CTRL+SHIFT+SPACE` | bascule de layout clavier | appelle `kb-layout-toggle` |
| `SUPER+code:58` | menu des keybindings | touche physique M (`,`/`?` en fr-mac) ; remplace `SUPER+K` et déplace `SUPER+comma` |
| `SUPER+H/J/K/L` | focus gauche/bas/haut/droite | jumeau des flèches ; libère `SUPER+J`/`SUPER+L` |
| `SUPER+ALT+J` / `SUPER+ALT+L` | toggle split / toggle layout | anciens `SUPER+J`/`SUPER+L` relogés |
| `SUPER+SHIFT+H/L` | empiler/désempiler dans la colonne | `consume_or_expel`, layout scrolling |
| `SUPER+ALT+F` | pleine largeur / cycle largeur colonne | `hypr-window-full-width` ; `SUPER+CTRL+F` délié (no-op en scrolling) |
| `SUPER+ALT+C` | centrer la colonne | `hypr-scrolling-center-column` |
| `SUPER+ALT+D` / `SUPER+D` | sauver / restaurer la largeur de fenêtre | remplace `SUPER+(ALT+)Home`, absent d'un 65 % |

**Scripts requis** (`~/.local/bin/`, sauvegardés ici) :
`kb-layout-toggle`, `hypr-window-full-width`, `hypr-scrolling-center-column`.
Vérifier que `~/.local/bin` est dans le `PATH` et que les fichiers sont `+x`.

## 3. Écrans — `~/.config/hypr/monitors.lua`

- `HDMI-A-1` ASUS VG28UQL1A — 3840x2160@119.88, scale **1.333333**, pos `0x0` → 2880x1620 logique
- `HDMI-A-2` ASUS VX229 — 1920x1080@60, scale 1, pos `2880x540` (aligné en bas)
- `GDK_SCALE = 1` (un seul scale global ne peut servir 1.333 et 1)
- Le catch-all `output = ""` d'Omarchy est **volontairement absent** : sinon
  `omarchy-hyprland-monitor-scaling` réécrirait le fichier sans effet visible.
  Corollaire : le bind de scaling (`SUPER+SLASH`) n'est pas persistant, il faut
  éditer ce fichier.

## 4. Apparence — `~/.config/hypr/looknfeel.lua`

- `gaps_in = 3`, `gaps_out = 6`, `border_size = 3` (défauts : 5 / 10 / 2)
- Animations accélérées à `speed = 1.0` (100 ms au lieu de ~380 ms) sur
  `windows`, `windowsIn/Out`, `border`, `fade`, `fadeIn/Out`
- `workspaces` et `specialWorkspace` : animations désactivées

## 5. Barre / shell Omarchy — `~/.config/omarchy/shell.json`

- **gauche** : `jvz.menu` (voir plus bas), `omarchy.workspaces`,
  `omarchy.active-window` (`maxWidth: 400`)
- **centre** : `omarchy.indicators`, `omarchy.clock`, `omarchy.keyboard-layout`,
  `omarchy.system-update`
- **droite** : `tray`, `io.github.thisisgm.omapods`, `agents`, `bluetooth`,
  `network`, `audio`, `monitor`, `power`
- horloge : `format = "dd dddd HH:mm"`, `formatAlt = "d MMMM 'W'ww yyyy"`,
  `birthYear = 2002`, `lifeExpectancy = 85`
- `omarchy.weather` retiré ; `omarchy.menu` dans `disabledPlugins`
- `idle` : `lock = 600`, `screensaver = 150`
- `~/.config/omarchy/shell.toml` : `font.base-size = 12`

## 6. Plugins shell

- **`jvz.menu`** — clone maison de `omarchy.menu` (`omarchy plugin clone omarchy.menu`
  puis renommé). Les fichiers sont sauvegardés ici en entier ; il suffit de les
  recopier dans `~/.config/omarchy/plugins/jvz.menu/`. Le `manifest.json` garde
  `omarchy.clonedFrom = "omarchy.menu"`.
- **`io.github.thisisgm.omapods`** — externe, `https://github.com/thisisgm/omarchy-pods`.
  Recloné automatiquement par `restore.sh`. Contrôle les AirPods
  (binaires `librepods` / `librepods-ctl` dans `~/.local/bin`, non sauvegardés ici).
- Menu custom : `~/.config/omarchy/extensions/omarchy-menu.jsonc` + `menu.sh`.

## 7. Autres

| Fichier | Modif |
|---|---|
| `.config/foot/foot.ini` | police taille 14 ; `clipboard-copy/paste` réduits à `Control+Insert` / `Shift+Insert` (libère `Ctrl+Shift+C/V`) |
| `.config/kitty/kitty.conf` | `listen_on` déplacé en fin de fichier |
| `.config/starship.toml` | modules `conda` et `python` ajoutés au prompt, venv seulement (`detect_env_vars = ["VIRTUAL_ENV"]`) |
| `.config/tmux/tmux.conf` | version antérieure sans les `-N` (descriptions) — **probablement à re-fusionner avec le défaut Quattro** |
| `.config/git/config` | `user.name = Jvaxx`, email, helpers credential `gh` |
| `.config/btop/btop.conf` | réglages perso |
| `.config/omarchy/defaults/agent` | `claude` |
| `.config/omarchy/hooks/post-update.d/setup-agent.hook` | invite de choix d'agent |
| `.config/omarchy/notes/` | notes perso (jellyfin/media worker) |

## Non sauvegardé volontairement

- `~/.config/nvim` → symlink vers `MaConfig/macos/nvim`, déjà versionné.
- Binaires (`librepods`, `librepods-ctl`) et wrappers d'agents dans `~/.local/bin` :
  réinstallés par leurs outils respectifs.
- Thèmes : aucun thème custom dans `~/.config/omarchy/themes/`.
- `~/.config/omarchy/branding/` : identique au stock.
- L'ancien dossier `../omarchy/` du repo date d'Omarchy 2.x (waybar, walker,
  fichiers `.conf`) — **obsolète**, ne pas restaurer sur Quattro.

## Après restauration — vérifications

```bash
hyprctl configerrors                      # doit être vide
hyprctl getoption input:kb_layout         # frmac,qwertyansi
xkbcli compile-keymap --layout frmac,qwertyansi --variant ansi,ansi \
    --options caps:escape_shifted_capslock,altwin:swap_lalt_lwin >/dev/null && echo "xkb OK"
ls -l ~/.local/bin/{kb-layout-toggle,hypr-window-full-width,hypr-scrolling-center-column}
omarchy restart shell
```
