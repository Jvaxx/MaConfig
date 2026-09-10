# Ce qui n'a pas suivi sur le MacBook

Audit de l'élagage `quattro` (Arch/Hyprland/x86_64/NVIDIA) → `asahi`
(Fedora/KDE/aarch64/pas de GPU). 232 paquets pacman en entrée, ~95 en sortie.

Rien n'est supprimé en silence : si un paquet ou un fichier manque sur le Mac,
il est ci-dessous avec la raison.

---

## 1. Paquets — infrastructure Arch (~25)

Sans objet sur Fedora, qui a son propre équivalent ou n'en a pas besoin.

`base` `base-devel` `fakeroot` `sudo` `yay` `pacman-contrib` `expac`
`kernel-modules-hook` `mkinitcpio` `linux` `linux-headers` `linux-firmware`
`limine` `limine-mkinitcpio-hook` `limine-snapper-sync` `snapper` `btrfs-progs`
`zram-generator` `plymouth` `efibootmgr` `dosfstools` `exfatprogs` `usage`
`man-db`\*

> Le bootloader (limine), l'initramfs (mkinitcpio) et les snapshots (snapper +
> btrfs) sont pris en charge côté Fedora par grub/dracut et un layout Btrfs
> différent. `zram-generator` existe déjà par défaut sur Fedora.
> \* `man-db` est conservé, il est juste dans les deux listes.

## 2. Paquets — matériel x86 / NVIDIA (~8)

`nvidia-open-dkms` `nvidia-utils` `lib32-nvidia-utils` `libva-nvidia-driver`
`amd-ucode` `ddcutil` `asdcontrol` `bolt`

> Aucun GPU NVIDIA ni microcode AMD sur M3. `ddcutil`/`asdcontrol` pilotent la
> luminosité d'écrans externes en DDC/CI — l'écran interne du MacBook passe par
> le backlight du noyau, et le HDMI est de toute façon désactivé sur M3 pour
> l'instant.

## 3. Paquets — pile Hyprland / Omarchy (~38)

`hyprland` `hyprland-guiutils` `hyprland-preview-share-picker` `hyprpicker`
`hyprsunset` `xdg-desktop-portal-hyprland` `xdg-desktop-portal-gtk` `uwsm`
`quickshell` `waybar` `walker` `sddm`\* `grim` `slurp` `wtype`
`xdg-terminal-exec` `wayland-pipewire-idle-inhibit` `udiskie`
`omarchy` `omarchy-keyring` `omarchy-nvim` `omarchy-settings` `omacalc`
`omacut` `omawrite` `aether` `herdr` `tobi-try` `tensaku` `ttfx`
`woff2-font-awesome` `yaru-icon-theme` `gnome-themes-extra`

> Plasma fournit son propre compositeur, portail, barre, lanceur, capture
> (Spectacle), automontage et gestion de veille.
> \* `sddm` est déjà là via Fedora KDE, inutile de le réinstaller.

Équivalents Plasma des captures/couleurs : `spectacle` (grim+slurp),
`kcolorchooser` (hyprpicker), Night Color intégré (hyprsunset).

## 4. Paquets — applis GNOME remplacées par KDE (~12)

| Arrive de quattro | Remplacé par (déjà dans Fedora KDE) |
|---|---|
| `nautilus`, `nautilus-python`, `sushi` | `dolphin` (+ aperçu intégré) |
| `evince` | `okular` |
| `imv` | `gwenview` |
| `gnome-disk-utility` | `partitionmanager` |
| `gnome-keyring`, `libsecret` | `kwalletmanager` |
| `gvfs-mtp`, `gvfs-nfs`, `gvfs-smb` | KIO (`kio-extras`) |
| `gnome-themes-extra` | Breeze |

## 5. Paquets — exigent un GPU, ou x86 seulement (~16)

`steam` `curseforge` `moonlight-qt` `obs-studio` `gpu-screen-recorder`
`kdenlive` `audacity` `lmstudio-bin` `zen-browser-bin` `openai-codex-desktop`
`typora` `chromium` `alacritty` `kitty` `spotify` `jellyfin-ffmpeg`

> **Le point central de cette machine.** Asahi n'a pas encore d'accélération 3D
> sur M3 : tout passe par llvmpipe (rendu CPU). Tout ce qui suppose OpenGL/Vulkan
> est soit injouable, soit un radiateur.
>
> `kitty` et `alacritty` sont dans cette liste et pas ailleurs : ce sont des
> terminaux **GPU**. C'est précisément pourquoi `foot` (rendu CPU) est le
> terminal retenu ici. `ghostty` (config dans `macos/`) est dans le même cas.
>
> `lmstudio-bin`, `curseforge`, `zen-browser-bin`, `typora`,
> `openai-codex-desktop` n'ont par ailleurs pas de build aarch64 Linux.

## 6. Paquets — spécifiques au site / au matériel de la maison (~8)

`songrec` `voxtype-bin` `asdcontrol` `freerdp` `tzupdate` `fcitx5`
`fcitx5-gtk` `fcitx5-qt` `mariadb-libs` `postgresql-libs` `dotnet-runtime`
`dotnet-runtime-9.0` `android-tools` `qemu-user-static-binfmt`

> `songrec` sert au bind SUPER+code:38 (Shazam) qui n'existe plus sans Hyprland.
> `fcitx5` : la saisie se fait via XKB + Compose ici, pas d'IME CJK configuré.
> `dotnet`/`mariadb`/`postgresql` : à réinstaller au cas par cas, selon les
> projets réellement ouverts sur cette machine.

## 7. Paquets — fournis d'office par Fedora KDE (~20)

Installés par la distribution, pas besoin de les lister :

`pipewire` `pipewire-alsa` `pipewire-jack` `pipewire-pulse` `wireplumber`
`gst-plugin-pipewire` `libpulse` `alsa-utils` `networkmanager` `bluez`
`bluez-tools` `bluez-utils` `avahi` `nss-mdns` `cups` `cups-filters`
`cups-pk-helper` `system-config-printer` `nfs-utils` `wireless-regdb`
`qt5-wayland` `qt6-connectivity` `qt6-imageformats` `qt6-tools`
`python-gobject` `brightnessctl` `power-profiles-daemon`

`ufw` / `ufw-docker` → Fedora utilise **firewalld**, actif par défaut.
`docker` / `docker-buildx` / `docker-compose` → remplacés par **podman**
(rootless par défaut) + `podman-docker` pour l'alias `docker`.

---

## 8. Fichiers de config non repris (29 sur 41)

### Hyprland — sans objet sous KWin
`.config/hypr/hyprland.lua` `bindings.lua` `input.lua` `looknfeel.lua`
`monitors.lua`

> `monitors.lua` décrit les écrans du poste fixe.

### Layouts XKB — `frmac`, `qwertyansi`
`.config/xkb/symbols/frmac` `.config/xkb/symbols/qwertyansi`

> **Non repris, et c'est le point important.** Ces deux layouts ont été écrits
> pour faire **imiter le comportement du Mac à un clavier PC** sur le poste fixe.
> Sur le MacBook, ce comportement est celui par défaut : les réglages clavier
> Plasma d'origine sont déjà la cible, il n'y a rien à installer ni à activer.
>
> Corollaire : `libxkbcommon-tools` et `xkbcomp` ne sont pas dans `packages.dnf`,
> et l'étape « layout clavier » a disparu de RESTORE.md.

### Omarchy — le shell, le menu, les extensions
`.config/omarchy/shell.json` `shell.toml`
`.config/omarchy/plugins/jvz.menu/` (4 fichiers QML/JS)
`.config/omarchy/extensions/omarchy-menu.jsonc` `menu.sh`
`.config/omarchy/defaults/agent`
`.config/omarchy/hooks/post-update.d/setup-agent.hook`
`.local/state/omarchy/workspace-layouts/{1,2,4}.lua`
plugins externes : `io.github.jvaxx.scrolling-position`,
`io.github.thisisgm.omapods`

> Tout ça tourne dans Quickshell, piloté par le binaire `omarchy`. Rien de
> transposable à Plasma sans réécriture complète.

### Scripts de keybinding — le bind qui les appelait n'existe plus
`.local/bin/kb-layout-toggle` `hypr-window-full-width` `omarchy-shazam`
`bbox-mic` `bbox-mic-bridge` + `.config/systemd/user/bbox-mic-bridge.service`

> `kb-layout-toggle` appelle `hyprctl switchxkblayout` : sous Plasma, le
> basculement frmac↔qwertyansi se règle dans Réglages > Clavier (voir RESTORE.md).
> `bbox-mic*` parle au micro de la télécommande Bbox du salon — sans objet sur un
> portable, et le service systemd utilisateur échouerait au démarrage.

### Web apps et lanceurs
`.local/share/applications/{Claude,Perplexity}.desktop`
`.local/share/icons/hicolor/256x256/apps/{claude,perplexity}.png`

> Générés par `omarchy webapp install`, ils lancent `omarchy-launch-webapp`.
> À recréer à la main en `.desktop` Plasma pointant vers le navigateur si besoin.

### Terminal
`.config/kitty/kitty.conf` — kitty n'est pas installé (GPU, cf. §5).

### Shell
Trois blocs retirés de `.bashrc` (documenté en tête du fichier `asahi/home/.bashrc`) :

| Bloc | Raison |
|---|---|
| `source "$OMARCHY_PATH/default/bash/rc"` | fichier inexistant hors Omarchy — remplacé par `~/.config/shell/{envs,aliases,init}.bash` |
| init conda / `__conda_hashr` | pas de miniforge3 installé ici |
| PATH grok | installeur x86_64 seulement |
| PATH LM Studio (×2) | x86_64, et demande un GPU |

Aliases Omarchy volontairement **non** repris car ils appellent des binaires
absents : `a` (omarchy-agent), `c`/`cx`/`cy` (opencode/claude/codex),
`h` (herdr), `ic`/`ix`/`icx` (tdl), `r` (rails), `mup` (mise), `try`.
Les autres (`ls`/`lt` eza, `cd`→zoxide, `ff` fzf, `g*` git, `n` nvim, `..`)
sont dans `shared/home/.config/shell/aliases.bash`.

---

## 9. Divergences volontaires (repris mais modifiés)

| Fichier | Modification | Pourquoi |
|---|---|---|
| `.config/foot/foot.ini` | palette gruvbox-material inlinée | l'`include=~/.local/state/omarchy/current/theme/foot.ini` n'existe pas, et foot refuse de démarrer sur un include manquant |
| `.config/btop/btop.conf` | `color_theme` : `"current"` → `"gruvbox_material_dark"` | `current` est un symlink posé par le sélecteur de thème Omarchy ; le thème visé est fourni de base par btop |
| `.XCompose` | `include "/usr/share/omarchy/default/xcompose"` → `include "%L"` + deux fichiers partagés | le xcompose Omarchy n'existe pas ici ; ses 24 emoji + la typographie sont recopiés dans `shared/home/.config/xcompose/emoji`, les règles perso dans `.../personal`. quattro inclut la version Omarchy et **pas** `emoji`, pour éviter le doublon |
| `neovim` | tarball officielle aarch64 au lieu du RPM | Fedora 43 = 0.11.x, or `init.lua` appelle `vim.pack.add()` (0.12+) |
