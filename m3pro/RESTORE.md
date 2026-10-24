# Restauration de ma config Omarchy — MacBook Pro M3 Pro

MacBook Pro 14" M3 Pro (`MBP14OmarchyDev`, « System B »), Arch Linux ARM +
Omarchy 4.0.3rc4 (omarchy-mac), noyau maison. Le but est d'être **au plus près
de Quattro** (le fixe, `../quattro/`) tout en restant un portable : clavier Mac
intégré, un seul écran Retina avec encoche, batterie, aarch64 / pages de 16 Ko.

Les fichiers repris de Quattro sont des **copies adaptées** dans `home/`, pas
des liens vers `../quattro/home` : une modif faite ici ne touche jamais le
fixe. Pour voir l'écart : `diff -r quattro/home m3pro/home`.

Ce dépôt ne couvre que `$HOME`. Le noyau, la pile GPU, `/etc`, la limite de
charge (`~/b-charge-limit.sh`) et les correctifs du shell
(`~/b4-shell-fixes.sh`) relèvent du projet OmarchyM3 (notes sur FIXEJVZ,
`~/Documents/OmarchyM3/handoff.md`), et toute installation passe par le skill
Claude `b-install` (sauvegardé ici).

## Restauration rapide

```bash
cd ~/Documents/MaConfig/m3pro
./restore.sh --dry-run   # voir ce qui serait écrit
./restore.sh             # restaurer (sauvegarde l'existant en *.bak.<timestamp>)
(cd ~/.claude/mods/math-render/helper && npm ci --ignore-scripts)
omarchy restart xcompose
```

Mêmes scripts que Quattro (`lib.sh`, `restore.sh`, `sync.sh`), même MANIFEST
(`copy:`, `shared:`), même `UNTRACKED`. Seule différence de `lib.sh` : les
anciennes versions de `~/.claude/skills/*` sont sauvegardées, comme les
plugins, dans `~/.local/state/maconfig/backups/`, sinon Claude Code les charge
comme des skills en double.

## Sauvegarde (après une modif)

```bash
cd ~/Documents/MaConfig/m3pro
./sync.sh --dry-run
./sync.sh            # ou --commit (commit limité à m3pro/ et shared/home)
```

Tests isolés : `python3 -B -m unittest discover -s m3pro/tests -v`.

---

# Ce qui est repris de Quattro, et comment

| Fichier | Par rapport à Quattro |
|---|---|
| `hypr/bindings.lua` | identiques, sauf ce qui est listé plus bas comme non repris. Mêmes touches physiques : le clavier Mac a nativement l'ordre Ctrl, Option, Cmd, Espace que Quattro obtient avec `altwin:swap_lalt_lwin`. ALT = Option **gauche** (l'Option droite est AltGr). `code:58` = touche `, ?`, `code:38` = touche `Q` |
| `hypr/input.lua` | layout `frmacbook` (voir plus bas) au lieu de `frmac`/`qwertyansi`, qui imitent ce clavier sur un clavier PC ; `caps:escape_shifted_capslock`, répétition 60 / 170 comme Quattro ; plus le touchpad façon macOS (tap, glisser à 3 doigts, workspaces à 4 doigts) |
| `hypr/looknfeel.lua` | identique + `cursor:no_hardware_cursors` (pas de curseur matériel sur ce GPU) |
| `hypr/hyprland.lua` | règle scratchpad en scrolling ; règles `render_unfocused` des jeux non reprises |
| `hypr/monitors.lua` | **non suivi**, reste le défaut : écran interne `eDP-1`, scale auto (2), `GDK_SCALE=2`, ce qui garde `SUPER+SLASH` persistant |
| `omarchy/shell.json` | même barre, mais le groupe du centre (mises à jour, indicateurs, horloge, layout clavier) est **à droite** : le centre de la barre est sous l'encoche. `idle.lock = 300` au lieu de 600 (le verrou éteint l'écran 5 s après) ; économiseur désactivé comme sur Quattro |
| `jvz.menu`, `jvz.tray` | **reclonés depuis le stock de cet Omarchy**, pas copiés : les clones de Quattro viennent d'une autre version et gardent un `import QtQuick` nu, que Qt 6.12 casse ici (cf. `~/b4-shell-fixes.sh`). Mêmes retouches : classement de la recherche du menu, AppLibrary propre au menu, tiroir du tray toujours ouvert |
| terminaux | `foot.ini` et `ghostty/config` identiques ; **foot est le terminal par défaut** (`xdg-terminals.list`, comme l'écrit `omarchy default terminal foot`), là où Quattro utilise Ghostty ; Ghostty reste installé et configuré. Copier/coller : `SUPER+C` / `SUPER+V` (Cmd+C / Cmd+V), qui envoient Ctrl/Shift+Insert, absents du clavier Mac |
| `.bashrc` | le bashrc Omarchy (l'image avait laissé celui d'Arch), `alias v.`, direnv protégé par `command -v` |
| `btop.conf` | celui de cette machine (pas de section GPU dans ce btop) avec `update_ms = 1000` de Quattro |
| `.claude/settings.json` | celui de Quattro sans le bloc `autoMode` (il décrit le HOME du fixe) |
| `omarchy-shazam` | identique + message clair si `songrec` manque |
| partagés | `nvim`, `starship`, `tmux`, `git/config`, `xcompose/personal`, `CLAUDE.md` |

Le helper credential de `shared/.../git/config` est `!gh auth git-credential`
(résolu par le PATH) : ici `gh` vient de mise, pas de `/usr/bin`.

## Non repris de Quattro, volontairement

| Quoi | Pourquoi |
|---|---|
| layouts XKB `frmac` / `qwertyansi`, `kb-layout-toggle`, `CTRL+SHIFT+SPACE` | `fr(mac)` est déjà le clavier physique ; un seul layout |
| micro Bbox (`bbox-mic`, `bbox-mic-bridge`, `SUPER+ALT+X`) | la télécommande est appairée au fixe |
| `nightlight-dim` | il y a un vrai rétroéclairage ici, et la boucle (3 processus toutes les 2 s) coûte de la batterie. Il marcherait : le démon shader comprend `gamma` |
| règles `render_unfocused` Factorio/KSP | jeux x86_64, rien ne les fait tourner ici |
| `monitors.lua` du fixe | deux écrans HDMI propres au fixe |
| kitty | non installé ici |
| voxtype (dictée F9), OBS Studio | pas voulus sur cette machine |
| `omarchy/notes`, `extensions/` | notes du serveur média ; les extensions de menu de Quattro sont les exemples stock |
| conda, grok, LM Studio dans `.bashrc` | non installés (LM Studio n'existe pas en aarch64) |
| plugins `blakestarling.workspace-presets`, `io.github.jvaxx.scrolling-position` | pas encore installés : plugins externes, à relire avant (règle 6 de `b-install`), voir plus bas |

## Propre au M3 Pro

- **Layout `frmacbook`** (`~/.config/xkb/symbols/frmacbook`) : `fr(mac)` avec
  Cmd droit = AltGr et Option droite = Super, et les deux touches ISO remises
  dans l'ordre de leurs étiquettes (`@ #` sous Échap, `< >` à droite de Maj
  gauche ; le noyau les inverse sur ce clavier, `hid_apple iso_layout` en
  auto). Session graphique seulement : console et invite LUKS gardent l'ordre
  du noyau. Après un changement de layout, `omarchy restart xcompose`
  (relance fcitx5, dont le clavier virtuel garde sinon l'ancien keymap).
- **Fn/Globe <-> Ctrl gauche** (hors `$HOME`, donc pas restauré par
  `restore.sh`) : `hid_apple swap_fn_leftctrl=1` dans
  `/etc/modprobe.d/hid_apple.conf`, posé le 2026-10-24 par
  `sudo bash ~/b-fn-ctrl-swap.sh on` (retour : `off` ; état : `status`).
  Impossible en XKB : Fn est `KEY_FN` (464), au-delà des 255 codes d'XKB.
  `hid_apple` étant chargé depuis l'initramfs, seule l'image du noyau par
  défaut (`linux-j514s-sleep-chg`) a été reconstruite ; les trois autres
  le prendront à leur prochaine reconstruction (`mkinitcpio -P`). Vaut aussi
  pour la console et l'invite LUKS. Si `iso_layout` est un jour réglé dans ce
  fichier, retirer les deux touches ISO de `frmacbook` (double inversion).
- **Veilleuse par shader** : `~/.local/lib/nightlight-shader/hyprsunset` +
  `nightlight-shader.service`. `appledrm` n'a pas de CTM, le vrai hyprsunset
  échoue ; ce démon sert le même socket et teinte via `screen_shader`.
  Installeur et tests : `~/nightlight-shader/`.
- **Skill `b-install`** (`~/.claude/skills/b-install`) : règles d'installation
  de cette machine.
- `omarchy-brightness-keyboard-auto.service` est masqué (lien vers
  `/dev/null`) ; non suivi par le MANIFEST, à refaire à la main :
  `systemctl --user mask omarchy-brightness-keyboard-auto.service`.

## Reste à faire (avec `b-install`)


1. Paquets requis par cette config (installés le 2026-10-24 ; à refaire
   après une réinstallation) :
   `sudo pacman -S --needed ghostty songrec direnv`
   puis `bash ~/.claude/skills/b-install/b-install-check.sh post`.
   Ghostty n'est pas le terminal par défaut ici (foot) ; il passe par le GPU
   (pile Mesa de dev) : le tester une fois avant de s'y fier.
2. Plugins externes de Quattro : `omarchy plugin add <url>` sans `--enable`,
   relire le code, vérifier le snapshot du marketplace et les `import QtQuick`
   nus, puis les remettre dans `shell.json` et `external-plugins.txt`.
3. Neovim : le premier lancement télécharge les plugins vim.pack, le binaire
   de blink.cmp et les LSP Mason ; certains LSP Mason n'ont pas de build arm64.

## Après restauration — vérifications

```bash
hyprctl configerrors                        # doit être vide
hyprctl getoption general:layout            # scrolling
hyprctl getoption input:kb_layout           # frmacbook
hyprctl getoption input:kb_options          # caps:escape_shifted_capslock
hyprctl getoption cursor:no_hardware_cursors  # 1
omarchy plugin list | grep jvz              # jvz.menu, jvz.tray enabled
systemctl --user is-active nightlight-shader  # active
./sync.sh --dry-run                         # aucun « Non suivis »
```
