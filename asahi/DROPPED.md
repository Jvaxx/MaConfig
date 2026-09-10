# Ce qui ne suit pas automatiquement depuis quattro

Portage du poste Arch/Hyprland/Omarchy/x86_64 vers Fedora Asahi Remix/KDE/aarch64.
Cette liste décrit les **choix du profil**, pas une matrice exhaustive de support
matériel ou logiciel. La liste effective reste `packages.dnf` + `bootstrap.sh`;
les versions téléchargées sont dans `assets.json`.

Le M3 Pro concerné n'a pas encore d'accélération GPU dans son installation.
La veille, les sorties vidéo, le décodage et les périphériques dépendent du noyau
et du matériel: aucun script ne tente de les activer ou de remplacer leur pile.

## 1. Infrastructure Arch et démarrage

Non importés: `base`, `base-devel`, `fakeroot`, `yay`, `pacman-contrib`, `expac`,
`kernel-modules-hook`, `mkinitcpio`, `linux`, `linux-headers`, `linux-firmware`,
`limine`, `limine-mkinitcpio-hook`, `limine-snapper-sync`, `snapper`, ainsi que
les configurations de boot, initramfs, partitions et snapshots du poste fixe.

Fedora/Asahi gère son propre démarrage. Ne pas supposer que le schéma de partitions
est Btrfs ou identique à celui du PC. Les utilitaires comme `sudo`, `btrfs-progs`,
`dosfstools`, `exfatprogs`, `efibootmgr`, `zram-generator`, `plymouth` peuvent
exister sur Fedora, mais ne sont pas réinstallés pour imiter Arch. `man-db` est
conservé. Les compilateurs/outils de build sont listés explicitement au tier 2.

## 2. Matériel du poste fixe

Non importés: `nvidia-open-dkms`, `nvidia-utils`, `lib32-nvidia-utils`,
`libva-nvidia-driver`, `amd-ucode`, `ddcutil`, `asdcontrol`, `bolt`.

Les pilotes NVIDIA et le microcode AMD n'ont aucun rôle ici. Les autres outils
sont exclus faute de besoin établi sur ce portable, pas parce que leur nom
implique systématiquement une incompatibilité ARM. Aucun changement de noyau,
firmware, Mesa, gestion thermique, backlight ou énergie n'est appliqué.

## 3. Hyprland et Omarchy

Non importés: `hyprland`, `hyprland-guiutils`, `hyprland-preview-share-picker`,
`hyprpicker`, `hyprsunset`, `xdg-desktop-portal-hyprland`, `uwsm`, `quickshell`,
`waybar`, `walker`, `grim`, `slurp`, `wtype`, `xdg-terminal-exec`,
`wayland-pipewire-idle-inhibit`, `udiskie`, `omarchy`, `omarchy-keyring`,
`omarchy-nvim`, `omarchy-settings`, `omacalc`, `omacut`, `omawrite`, `aether`,
`herdr`, `tobi-try`, `tensaku`, `ttfx`, `woff2-font-awesome`, `yaru-icon-theme`,
`gnome-themes-extra`.

Plasma apporte KWin, ses portails/lanceurs et ses propres intégrations. On ne
supprime aucun portail GTK éventuellement nécessaire aux applications installées,
et on ne remplace pas SDDM. Spectacle, Night Color et les réglages Plasma couvrent
certains usages de grim/slurp/hyprsunset; les binds ne sont pas transposés.

Configs/scripts exclus:

- `.config/hypr/{hyprland,bindings,input,looknfeel,monitors}.lua`;
- `.config/omarchy/`, plugins Quickshell et états de workspaces Omarchy;
- `.local/bin/kb-layout-toggle`, `hypr-window-full-width`, `omarchy-shazam`;
- `.local/bin/bbox-mic`, `bbox-mic-bridge` et son service utilisateur;
- lanceurs web Claude/Perplexity appelant `omarchy-launch-webapp`.

Un lanceur web indépendant peut être recréé depuis le navigateur/KDE. Les scripts
Bbox sont spécifiques au matériel du salon; aucun service n'est importé.

## 4. Applications GNOME et intégration KDE

Le profil ne réinstalle pas `nautilus`, `nautilus-python`, `sushi`, `evince`,
`imv`, `gnome-disk-utility`, `gvfs-mtp`, `gvfs-nfs`, `gvfs-smb` pour copier le PC.
Les applications/intégrations KDE (Dolphin, Okular, Gwenview, Partition Manager,
KIO) couvrent les besoins courants; leur présence dépend de l'installation.

**KWallet n'est pas un remplacement RPM universel de libsecret/gnome-keyring.**
Les applications et Flatpaks peuvent nécessiter Secret Service ou d'autres
intégrations. Laisser les dépendances de Fedora gérer cela; ne rien désinstaller
au nom du portage.

## 5. Logiciels graphiques exclus par prudence ou préférence

Le profil initial a omis: `steam`, `curseforge`, `moonlight-qt`, `obs-studio`,
`gpu-screen-recorder`, `kdenlive`, `audacity`, `lmstudio-bin`, `zen-browser-bin`,
`openai-codex-desktop`, `typora`, `chromium`, `alacritty`, `kitty`, `spotify`,
`jellyfin-ffmpeg`. Ghostty n'est pas importé non plus.

Ce n'est **pas** une liste de logiciels exigeant tous un GPU ou impossibles sur
ARM64. Audacity, notamment, ne nécessite pas d'accélération GPU. Chromium et
d'autres applications peuvent utiliser un rendu logiciel. La disponibilité des
builds upstream évolue: vérifier séparément architecture et performances avant
d'ajouter une application.

Foot est retenu pour son rendu CPU; Konsole reste utilisable. Les terminaux à
rendu GPU sont simplement hors du profil. Les Flatpaks LocalSend/Obsidian/Signal
ont des builds ARM64 lors de l'audit, mais Flutter/Electron peuvent rester coûteux
en rendu logiciel. Ils sont au tier 4, pas installés par un bootstrap CLI seul.
Mpv dispose d'une config locale de sortie logicielle (`wlshm`, repli `x11`).

## 6. Outils liés aux usages du PC

Non réinstallés automatiquement: `songrec`, `voxtype-bin`, `freerdp`, `tzupdate`,
`fcitx5`, `fcitx5-gtk`, `fcitx5-qt`, `mariadb-libs`, `postgresql-libs`,
`dotnet-runtime`, `dotnet-runtime-9.0`, `android-tools`, `qemu-user-static-binfmt`.

L'absence de leurs binds/projets/IME motive ce choix. Ajouter les runtimes et
services selon les besoins réels; l'émulation x86 n'est pas activée implicitement.

## 7. Services et conteneurs

PipeWire/WirePlumber, NetworkManager, Bluetooth, impression, portails, firewalld
et gestion d'énergie restent sous le contrôle de Fedora KDE. Le profil ne
prétend pas que tous les paquets Arch de même rôle sont préinstallés, ni qu'ils
portent les mêmes noms Fedora. Aucune de ces intégrations n'est supprimée.

Docker est remplacé dans la sélection par Podman, `podman-docker` et
`podman-compose`. **Le socket utilisateur et DOCKER_HOST restent opt-in** pour
lazydocker; voir RESTORE.md. Cela ne garantit pas une compatibilité totale avec
les stacks Docker du PC.

## 8. Clavier et shell

Les layouts personnalisés `frmac`/`qwertyansi` restent **locaux à quattro**.
Ils ne sont pas installés sur le MacBook et aucune disposition Plasma n'est
imposée. Vérifier la variante existante et assigner une touche Compose; le simple
fait d'avoir un clavier Apple ne sélectionne pas les conventions macOS sous Linux.

Les règles Compose personnelles et emoji sont partagées. Le `.XCompose` Asahi
inclut `%L` plutôt que `/usr/share/omarchy/default/xcompose`; quattro continue de
charger la version Omarchy et n'inclut pas le fichier emoji partagé.

Retirés du shell Asahi: source du rc Omarchy, conda/miniforge du PC, PATH grok et
LM Studio, et alias dépendant d'outils Omarchy absents. Conservés: les préférences
CLI portables, **NVM déjà présent sur le Mac**, les fragments `.bashrc.d` et les
overrides locaux hors Git. Les chemins Cargo/Go/local/bin sont pris en charge.

## 9. Divergences locales et corrections de compatibilité

| Élément | Choix Asahi |
|---|---|
| foot | palette intégrée, syntaxe foot 1.27 `[colors-dark]`, raccourcis sans Insert obligatoire |
| btop | thème gruvbox distribué, rafraîchissement 2 s, affichage GPU désactivé |
| mpv | sortie CPU Wayland, aucun décodage matériel supposé |
| Neovim | RPM Fedora >= 0.12, pas d'installateur tarball destructif |
| Tree-sitter CLI | RPM Fedora; parsers compilés localement |
| LSP | serveurs système explicitement activés; Mason complète les absences |
| lazygit | archive ARM64 épinglée/vérifiée; abandon du COPR atim non maintenu |
| Nerd Font | archive officielle épinglée/vérifiée; le COPR précédemment référencé n'existe pas |
| restore/sync | validation, staging, backups conservés, erreurs non masquées, commit limité au MANIFEST |

`shared/home` ne contient que les configurations communes effectivement utilisées
(nvim, shell, tmux, git, starship, xcompose). Il ne contient pas les layouts XKB.
Les scripts de sauvegarde historiques de quattro/macOS ne sont pas remplacés par
ce correctif Asahi; leurs contraintes propres doivent être auditées séparément.
