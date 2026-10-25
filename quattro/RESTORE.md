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

`restore.sh` installe des **symlinks** de `$HOME` vers les entrées de `home/`,
reclone les plugins shell externes listés dans `external-plugins.txt`, active
les unités systemd user du MANIFEST qui ont une section `[Install]`, puis
recharge Hyprland, le shell Omarchy et les terminaux.
`--no-reload` installe sans rien activer ni relancer. Les liens déjà corrects
sont conservés ; chaque fichier/dossier remplacé est sauvegardé en `.bak.*`.
Exception : les anciens plugins vont dans `~/.local/state/maconfig/backups/`
pour éviter que le shell découvre leurs sauvegardes comme plugins doublons.
**Ne pas déplacer/supprimer le dépôt**, qui devient la config active.

Exceptions `copy:` (réécrites par leur application, un lien casserait) :
`shell.json` (les commandes Omarchy le remplacent par renommage atomique),
`btop.conf` (préférences réécrites à la fermeture) et les presets de
`blakestarling.workspace-presets` (ouverts en `O_NOFOLLOW`).
Une copie locale **plus récente** que celle du dépôt n'est pas écrasée par
`restore.sh` (elle n'est simplement pas encore sauvegardée) : `sync.sh`
l'importera. Supprimer le fichier local pour forcer la version du dépôt.
Les plugins externes gardent leurs propres dépôts, sans lien vers MaConfig.

Certaines entrées viennent de `../shared/home` et non de `home/` : ce sont
celles préfixées `shared:` dans le MANIFEST, partagées avec les autres hôtes.
Voir la section Structure plus bas.

## Sauvegarde (après une modif)

```bash
cd ~/Documents/MaConfig/quattro
./sync.sh --dry-run  # vérifier sans écrire
./sync.sh            # vérifier les liens, copier les exceptions, exporter les inventaires
./sync.sh --commit   # + commit git
git push
```

Les modifications des fichiers liés sont immédiatement visibles dans `git diff`.
`sync.sh` refuse toute écriture si un lien est absent/remplacé : comparer alors
la copie locale au dépôt, fusionner les changements utiles, puis relancer
`restore.sh`. Il ne réimporte jamais silencieusement une ancienne copie locale.
Avant un pull, synchroniser les exceptions puis commiter/stasher les changements.

**Configs oubliées** : `sync.sh` (y compris `--dry-run`) liste sous « Non suivis »
ce qui a été personnalisé sans être sauvegardé : les fichiers de `~/.config`
qui diffèrent de leur défaut dans `/usr/share/omarchy/config`, et les fichiers
(pas les liens) de `~/.local/bin`, `~/.config/systemd/user`, `~/.config/hypr`,
`wireplumber.conf.d` et des hooks/extensions Omarchy. Pour chacun : l'ajouter au
MANIFEST, ou l'écarter dans `UNTRACKED` en disant pourquoi.

Pour ajouter un fichier : le copier d'abord dans `home/` (ou `../shared/home/`),
ajouter son chemin relatif à `$HOME` au `MANIFEST`, puis lancer `restore.sh`.
Préfixer par `shared:` pour l'arbre partagé, `copy:` pour une exception
(`copy:shared:` est également accepté). Comparer les copies avant restauration :
le dépôt est prioritaire, les anciennes copies sont sauvegardées, pas fusionnées.

Tests isolés : `python3 -B -m unittest discover -s quattro/tests -v`.

## Structure

| Chemin | Rôle |
|---|---|
| `MANIFEST` | liste des fichiers suivis (`shared:` = vient de `../shared/home`) |
| `UNTRACKED` | configs volontairement non suivies (motifs glob), tues par l'audit de `sync.sh` |
| `home/` | fichiers propres à cet hôte, arborescence `$HOME` |
| `../shared/home/` | fichiers partagés avec les autres hôtes, même arborescence |
| `sync.sh` / `restore.sh` / `lib.sh` | vérification + audit + exports / installation des liens |
| `STATE` | version Omarchy + date du dernier sync |
| `external-plugins.txt` | plugins shell clonés depuis GitHub (`id<TAB>url`) |
| `packages.txt` | `pacman -Qqe` au dernier sync — **référence seule**, `restore.sh` n'installe rien |

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
| `SUPER+SHIFT+A` / `SUPER+SHIFT+C` | web apps Perplexity / Claude | remplacent ChatGPT / HEY Calendar |
| `CTRL+SHIFT+SPACE` | bascule de layout clavier | appelle `kb-layout-toggle` |
| `SUPER+code:58` | menu des keybindings | touche physique M (`,`/`?` en fr-mac) ; remplace `SUPER+K` et déplace `SUPER+comma` |
| `SUPER+H/J/K/L` | focus gauche/bas/haut/droite | jumeau des flèches ; libère `SUPER+J`/`SUPER+L` |
| `SUPER+ALT+J` / `SUPER+ALT+L` | toggle split / toggle layout | anciens `SUPER+J`/`SUPER+L` relogés |
| `SUPER+SHIFT+H/L` | empiler/désempiler dans la colonne | `consume_or_expel`, layout scrolling |
| `SUPER+ALT+F` | pleine largeur / cycle largeur colonne | `hypr-window-full-width` ; `SUPER+CTRL+F` délié (no-op en scrolling) |
| `SUPER+ALT+D` / `SUPER+D` | sauver / restaurer la largeur de fenêtre | remplace `SUPER+(ALT+)Home`, absent d'un 65 % |
| `SUPER+code:38` | Shazam | voir §9 |
| `SUPER+ALT+X` | dictée via le micro de la télécommande Bbox | voir §9 |

**Scripts requis** (`~/.local/bin/`, sauvegardés ici) :
`kb-layout-toggle`, `hypr-window-full-width`, `omarchy-shazam`, `bbox-mic`.
Vérifier que `~/.local/bin` est dans le `PATH` et que les fichiers sont `+x`.

## 3. Écrans — `~/.config/hypr/monitors.lua`

- `HDMI-A-1` ASUS VG28UQL1A — 3840x2160@119.88, scale **1.6**, pos `0x0` → 2400x1350 logique
- `HDMI-A-2` ASUS VX229 — 1920x1080@60, scale 1, pos `2400x270` (aligné en bas)
- `GDK_SCALE = 1` (un seul scale global ne peut servir 1.6 et 1)
- Workspaces 1–4 sur le 4K, 5–6 sur le 1080p (repli sur l'écran restant si
  le 1080p est débranché).
- Le catch-all `output = ""` d'Omarchy est **volontairement absent** : sinon
  `omarchy-hyprland-monitor-scaling` réécrirait le fichier sans effet visible.
  Corollaire : le bind de scaling (`SUPER+SLASH`) n'est pas persistant, il faut
  éditer ce fichier.

## 4. Apparence et layout — `looknfeel.lua`, `hyprland.lua`

- `gaps_in = 2`, `gaps_out = 2`, `border_size = 2` (défauts : 5 / 10 / 2)
- Layout **scrolling** par défaut sur tous les workspaces (`SUPER+ALT+L` enregistre
  des exceptions par workspace dans `~/.local/state/omarchy/workspace-layouts`,
  sauvegardé), et sur le scratchpad (`hyprland.lua`).
- `scrolling.focus_fit_method = 1` (fit, le défaut ; le centrage a été essayé puis abandonné)
- Animations accélérées à `speed = 1.0` (100 ms au lieu de ~380 ms) sur
  `windows`, `windowsIn/Out`, `border`, `fade`, `fadeIn/Out`
- `workspaces` et `specialWorkspace` : animations désactivées
- `hyprland.lua` : `render_unfocused` pour Factorio et KSP (`render_unfocused_fps = 60`),
  pour que la simulation ne gèle pas quand la fenêtre est cachée.

## 5. Barre / shell Omarchy — `~/.config/omarchy/shell.json`

- **gauche** : `jvz.menu` (voir plus bas), `omarchy.workspaces`,
  `blakestarling.workspace-presets`, `io.github.jvaxx.scrolling-position`,
  `omarchy.active-window`
- **centre** : `omarchy.indicators`, `omarchy.clock`, `omarchy.keyboard-layout`,
  `omarchy.system-update`
- **droite** : `io.github.thisisgm.omapods`, `jvz.tray` (voir plus bas), `agents`,
  `bluetooth`, `network`, `audio`, `monitor`, `power`
- horloge : `format = "ddd d MMM HH:mm"`, `formatAlt = "d MMMM 'W'ww yyyy"`,
  `birthYear = 2002`, `lifeExpectancy = 85`
- `omarchy.weather` retiré ; `omarchy.menu` dans `disabledPlugins`
- `idle` : `lock = 600`, `screensaver = 86400` (de fait désactivé)
- `~/.config/omarchy/shell.toml` : `font.base-size = 12`

## 6. Plugins shell

- **`jvz.menu`** — clone maison de `omarchy.menu` (`omarchy plugin clone omarchy.menu`
  puis renommé). Le `manifest.json` garde `omarchy.clonedFrom = "omarchy.menu"`.
  Menu custom : `~/.config/omarchy/extensions/omarchy-menu.jsonc` + `menu.sh`.
- **`jvz.tray`** — clone maison de `omarchy.tray` (`omarchy plugin clone omarchy.tray`).
  Tiroir de la zone de notification toujours ouvert : dans `Tray.qml`, `expanded`
  est forcé à `true`, les `HoverHandler` d'expansion sont supprimés et le chevron
  `‹` (`expandIcon`) est masqué (`visible: false`, extent 0) dans les deux
  dispositions (horizontale et verticale). Conséquence : la popup « Tray icons »
  (pin/hide), ouverte par clic droit sur le chevron, n'est plus atteignable —
  pour masquer une icône, ajouter son id au tableau `"hidden"` de l'entrée
  `jvz.tray` dans `shell.json`. Retour au comportement stock : supprimer
  `~/.config/omarchy/plugins/jvz.tray/` et remettre `omarchy.tray` dans la barre.
- **Externes**, reclonés automatiquement par `restore.sh` (`external-plugins.txt`) :
  - `blakestarling.workspace-presets` — presets de workspaces ; les presets
    eux-mêmes (`~/.config/omarchy-workspace-presets/presets.json`) sont sauvegardés ici.
  - `io.github.jvaxx.scrolling-position` — plugin maison, dans son propre dépôt.
  - `io.github.thisisgm.omapods` — AirPods (binaires `librepods` / `librepods-ctl`
    dans `~/.local/bin`, non sauvegardés ici).

## 7. Autres

| Fichier | Modif |
|---|---|
| `.config/ghostty/config` | **terminal par défaut** (`xdg-terminals.list`) ; police 12 ; molette 5 lignes par cran, touchpad inchangé |
| `.config/foot/foot.ini` | police taille 12 ; `clipboard-copy/paste` réduits à `Control+Insert` / `Shift+Insert` (libère `Ctrl+Shift+C/V`) |
| `.config/kitty/kitty.conf` | police 9, sans décorations, copier/coller sur Ctrl/Shift+Insert, Shift+Enter et Alt+Shift+Enter en CSI-u, tab bar powerline ; `listen_on` en fin de fichier |
| `.config/starship.toml` | modules `conda`, `python` (venv seulement) et `hostname` (SSH seulement) |
| `.config/tmux/tmux.conf` | version antérieure sans les `-N` (descriptions) — **probablement à re-fusionner avec le défaut Quattro** |
| `.config/git/config` | `user.name = Jvaxx`, email, helpers credential `gh` |
| `.config/btop/btop.conf` | réglages perso |
| `.config/omarchy/defaults/agent` | `claude` |
| `.config/omarchy/hooks/post-update.d/setup-agent.hook` | invite de choix d'agent |
| `.config/omarchy/notes/` | notes perso (jellyfin/media worker) |

## 8. Environnement shell — `~/.bashrc`, `~/.bash_profile`, `~/.XCompose`

Ces trois fichiers sont à la **racine de `$HOME`**, pas dans `.config`.

- **`~/.bashrc`** : défaut Omarchy + conda (miniforge), PATH grok, PATH LM Studio,
  `direnv hook bash`, `alias v.='source .venv/bin/activate'`.
  Le no-op **`__conda_hashr() { :; }`** doit rester **sous** le bloc conda
  (`conda init` le réécrit) : les défauts Omarchy font `set +h` pour mise, donc
  le `hash -r` de conda ne ferait qu'afficher « hashing disabled » à chaque activate.
- **`~/.bash_profile`** : source `.bashrc` + PATH LM Studio.
- **`~/.XCompose`** : règles de composition maison, entièrement réécrit vs le
  défaut Omarchy (emoji stock retirés). Appliquer : `omarchy restart xcompose`.

## 9. Scripts maison

| Script | Déclencheur | Dépendances |
|---|---|---|
| `.local/bin/omarchy-shazam` | `SUPER + code:38` | paquet `songrec` |
| `.local/bin/bbox-mic` | `SUPER + ALT + X` | `bbox-mic-bridge` + son service |
| `.local/bin/bbox-mic-bridge` | service `bbox-mic-bridge` | python3, PipeWire, Bluetooth ; doc dans `~/Documents/bbox_remote/mic_info.md` |
| `.local/bin/nightlight-dim` | `hypr/autostart.lua` | `hyprsunset` ; baisse le gamma à `NIGHTLIGHT_GAMMA` % (70) quand le night light est actif |

`bbox-mic` n'est qu'un client : sans le service actif il s'arrête avec un message.
`restore.sh` active le service tout seul ; à la main :
`systemctl --user daemon-reload && systemctl --user enable --now bbox-mic-bridge`.

## 10. Claude Code — `~/.claude/`

- **`CLAUDE.md`** (partagé, `../shared/home/.claude/`) : règles des messages de
  commit. Sa dernière ligne `@~/.claude/pi.md` importe les consignes de
  délégation Pi, propres à cet hôte et **non sauvegardées** ; sans ce fichier,
  l'import est simplement ignoré.
- **`settings.json`** (`copy:`, réécrit par Claude Code) : modèle, effort,
  auto-compact, thème, attribution désactivée, plugin `frontend-design`. Contient
  aussi la permission `mcp__pi__investigate`, sans effet sans le serveur Pi.
- **`mods/math-render`** : mod maison (LaTeX rendu en images dans le terminal),
  chargé via `CLAUDE_CODE_PLUGIN_DIRS`. `node_modules` n'est pas versionné :
  après restauration, `cd ~/.claude/mods/math-render/helper && npm ci`.

## 11. Souris — Logitech G502 HERO (`libratbag`)

Les deux LED (logo = 0, bande DPI = 1) sont en **orange fixe à ~50 %**
(`803000`) au lieu du cyan respirant d'usine. Le réglage est écrit **dans la
mémoire de la souris** : rien à restaurer dans `$HOME`, il survit aux
réinstallations et aux autres machines. À refaire seulement après un reset de
la souris ou avec une nouvelle.

```bash
sudo pacman -S libratbag && sudo systemctl enable --now ratbagd
ratbagctl list                    # nom attribué, ex. thundering-gerbil
r=thundering-gerbil
ratbagctl $r profile 1 enable     # indispensable, voir ci-dessous
ratbagctl $r profile active set 1
for i in 0 1; do ratbagctl $r led $i set mode on color 803000; done
```

- **Piège** : d'usine, les 5 profils sont `(disabled)` et la souris tourne sur
  son profil ROM. `ratbagctl` écrit alors la couleur sans erreur, mais rien ne
  change : il faut activer le profil 1 pour que la souris le charge.
- Le profil 1 reprend les réglages d'usine : 1000 Hz, DPI 400/800/1600/2400
  (1600 par défaut), boutons standard.
- En mode `on`, pas de luminosité séparée : on assombrit via la couleur
  (`ff6000` plein, `803000` ~50 %, `401800` ~25 % ; `802000` si ça tire au jaune).
- `ratbagd` ne sert qu'à modifier les réglages ; on peut le désactiver ensuite.

## Non sauvegardé volontairement

La liste à jour, avec la raison de chaque exclusion, est dans **`UNTRACKED`**
(wrappers mise des agents, `livecaption`, `revtracker-pull`, `pi-investigate`,
`claude-token-refresh`...). En plus :

- Les fichiers hors `$HOME` : `/etc/lact/config.yaml` (limite de puissance GPU
  212 W) se refait à la main dans LACT.
- `~/.config/omarchy/branding/` (`about.txt`, `screensaver.txt`) : supposé stock,
  mais **non vérifiable** — plus aucun équivalent dans `/usr/share/omarchy`.
  À ajouter au MANIFEST si l'ASCII art compte.
- Thèmes : aucun thème custom dans `~/.config/omarchy/themes/`.
- `~/.config/mise/config.toml` (versions d'outils) : non suivi.
- Neovim : `lsp/kos_ls.lua` attend le binaire `kos-ls` (lien `~/.local/bin/kos-ls`
  vers `~/Projects/kos-ls`, dépôt séparé).

## Après restauration — vérifications

```bash
hyprctl configerrors                      # doit être vide
hyprctl getoption input:kb_layout         # frmac,qwertyansi
xkbcli compile-keymap --layout frmac,qwertyansi --variant ansi,ansi \
    --options caps:escape_shifted_capslock,altwin:swap_lalt_lwin >/dev/null && echo "xkb OK"
ls -l ~/.local/bin/{kb-layout-toggle,hypr-window-full-width,omarchy-shazam,bbox-mic,bbox-mic-bridge,nightlight-dim}
systemctl --user is-enabled bbox-mic-bridge   # enabled
pgrep -f nightlight-dim                       # lancé par autostart.lua
./sync.sh --dry-run                           # aucun « Non suivis » inattendu
omarchy restart xcompose
```
