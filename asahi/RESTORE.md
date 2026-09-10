# Fedora Asahi Remix / KDE — installation et sauvegarde

Profil pour **Fedora 44+ sur aarch64**, testé contre les métadonnées de cette
machine (M3 Pro, KDE Wayland). Les versions Fedora futures et les performances
GUI restent à vérifier; aucun script ne modifie le noyau, le bootloader, Mesa,
KWin, les réglages d'énergie ou la disposition clavier.

## Avant de commencer

- Lancer les scripts **comme utilisateur, sans `sudo` devant le script**.
  Seules les commandes DNF de `bootstrap.sh` utilisent sudo.
- `restore.sh`/`sync.sh` nécessitent Python 3 (bibliothèque standard seulement),
  déjà fourni sur Fedora KDE. Les wrappers Bash appellent `lib/config_io.py`.
- Lire `git status` et sauvegarder les modifications locales avant une migration.
- Le matériel Apple ne reproduit pas automatiquement le comportement de macOS
  sous Linux. Les réglages Plasma actuels sont conservés, pas remplacés.
- Sans accélération GPU, foot utilise un rendu CPU. Konsole reste une solution
  de repli; les applications Electron/Flutter peuvent fonctionner en rendu
  logiciel mais leur fluidité et leur autonomie ne sont pas garanties.

## Ordre conseillé

```bash
cd ~/Documents/MaConfig/asahi
./bootstrap.sh --dry-run
./bootstrap.sh
./restore.sh --dry-run
./restore.sh                  # ou --link, après lecture ci-dessous
exec bash -l
```

Une simulation n'installe rien, n'interroge pas les gestionnaires de paquets,
ne télécharge rien et ne modifie aucun fichier. Elle affiche le plan, mais
**ne valide pas la disponibilité réseau, les dépendances ou les performances**.
La durée réelle dépend des téléchargements et des compilations Cargo.

### Tiers et options

Les tiers filtrent **les RPM et les installations hors dépôts**. Sans `--tier`,
tous sont sélectionnés. Ils sont indépendants: tier 2 seul ne configure pas le
shell/éditeur du tier 1; pour un poste de développement, sélectionner 1 et 2.

| Tier | Contenu |
|---|---|
| 1 | CLI, Neovim RPM >= 0.12, starship COPR, lazygit ARM64 |
| 2 | Toolchains, Node 24 RPM, LSP système, Tree-sitter CLI, Podman; mise, uv, lazydocker, dua, diskonaut |
| 3 | foot, polices Fedora; JetBrainsMono Nerd Font utilisateur |
| 4 | Applications GUI et Flatpaks utilisateur LocalSend, Obsidian, Signal |

```bash
./bootstrap.sh --tier 1 --tier 2  # pas de polices/GUI Flatpak
./bootstrap.sh --tier 3          # terminal + polices uniquement
./bootstrap.sh --no-copr         # saute uniquement starship, pas les Nerd Fonts
./bootstrap.sh --skip-manual     # RPM/COPR seulement; Neovim reste un RPM
./bootstrap.sh --tier 1 --skip-manual --no-copr
```

`--skip-manual` saute lazygit, mise, uv, lazydocker, les builds Cargo, la police
Nerd Font et les Flatpaks. Le terminal utilise alors JetBrains Mono/Noto en
repli; certains glyphes d'icônes peuvent manquer. Les échecs restent visibles
et produisent un **code de sortie non nul**. Une erreur n'annule pas les
installations de paquets déjà réussies; corriger sa cause puis relancer.

### Sources et mises à jour

- **Neovim et tree-sitter-cli**: dépôts Fedora. Fedora 44 propose Neovim 0.12.x;
  pas de tarball Neovim, pas de suppression automatique d'un ancien binaire.
  Si le PATH sélectionne une ancienne installation, vérifier `type -a nvim`.
- **Node/npm**: `nodejs24`, `nodejs24-bin`, `nodejs24-npm`, `nodejs24-npm-bin`.
  Les paquets `-bin` exposent les noms non suffixés. NVM existant est conservé.
  Le Node système permet aussi aux outils lancés hors du shell d'avoir un runtime.
- **starship**: COPR `atim/starship`, activé explicitement pour
  `fedora-<version>-aarch64`. C'est un dépôt tiers de confiance, pas Fedora officiel.
- **lazygit, lazydocker, mise, uv, JetBrainsMono Nerd Font**: versions et SHA-256
  épinglés dans `assets.json`. `lib/install_asset.py` vérifie l'archive avant
  d'en copier les fichiers attendus; aucun `curl | sh`. Les binaires vont dans
  `~/.local/bin`, la police dans `~/.local/share/fonts/JetBrainsMonoNerd`.
  Les exécutables déjà présents dans le PATH sont conservés; ce bootstrap n'est
  pas un gestionnaire de mises à jour pour les outils hors dépôts.
- **dua-cli / diskonaut**: versions épinglées dans `bootstrap.sh`, compilation
  locale via `cargo install --locked`, sans privilèges. Cargo exécute les scripts
  de build des crates: cela suppose de faire confiance à ces projets/dépendances.
- **Flatpaks**: Flathub utilisateur, architecture aarch64 explicite. Les trois
  applications ont des builds ARM64 lors de l'audit. Pas de contournement x86.
  Une installation système existante n'est pas confondue avec le scope utilisateur.

Pour actualiser un asset, revoir **ensemble** version, URL, SHA-256 et chemins
internes depuis la release officielle. Puis vérifier sans installer/exécuter:

```bash
python3 -B lib/install_asset.py lazygit --verify-only
# Même commande pour lazydocker, mise, uv, jetbrains-mono.
```

Le checksum détecte une archive modifiée; il ne remplace pas la confiance dans
le projet upstream. Aucun service/socket n'est activé par le bootstrap.

## Restauration et shell local

`restore.sh` remplace les entrées du MANIFEST, **pas l'ensemble de `~/.config`**.
Les sources manquantes, chemins dangereux/imbriqués et liens non portables sont
refusés avant copie. Les fichiers sont tous préparés avant remplacement; leurs
anciennes versions restent dans `*.bak.<date>.<identifiant>`. Une erreur normale
pendant publication déclenche un retour aux anciennes versions. Ce n'est pas
une transaction résistante à toute panne électrique: conserver les backups et
inspecter les destinations après une interruption brutale.

`--link` pose des liens vers le dépôt; les modifications faites depuis les
applications affectent immédiatement Git. Un lien déjà correct est conservé,
même si l'on relance sans `--link`. Une copie identique n'est pas remplacée.
Pour revenir volontairement du lien à une copie, déplacer d'abord le lien hors
de sa destination et relancer le restore sans `--link`.

Les fichiers de shell sont **remplacés, pas fusionnés**:

- NVM est chargé s'il existe; `NVM_DIR` personnalisé est respecté.
- `~/.bashrc.d/*` continue d'être chargé comme dans le `.bashrc` Fedora.
- `~/.bashrc.local` et `~/.bash_profile.local` sont des overrides finaux.
- Ces trois emplacements restent **hors MANIFEST/Git**. Y déplacer les autres
  ajouts locaux utiles avant restauration; ne pas y sourcer tout l'ancien
  `.bashrc`, au risque d'initialisations en double ou d'une récursion.
- `~/.local/bin`, `~/bin`, `${CARGO_HOME:-~/.cargo}/bin` et le répertoire de
  binaires Go sont ajoutés au PATH sans doublons. NVM/mise peuvent ensuite
  sélectionner le runtime du projet; éviter de gérer le même projet avec les deux.
- Les shells login non interactifs reçoivent les chemins utilisateur, mais
  n'activent pas NVM, mise ou le prompt.

```bash
type -a node npm nvim
command -v nvm
node --version
nvim --version
```

Un `exec bash -l` hérite de l'ancien environnement. Tester aussi un **nouveau
terminal** (voire une nouvelle session Plasma) pour vérifier la persistance.

## Neovim

Le premier lancement clone les plugins épinglés dans `nvim-pack-lock.json`.
La compilation initiale des parsers peut prendre plusieurs minutes. Sans tier 2,
l'éditeur reste utilisable, mais les parsers absents ne sont pas compilés.

```vim
:checkhealth
:checkhealth vim.lsp
:Mason
```

- La configuration nécessite Neovim >= 0.12, Tree-sitter CLI >= 0.26.1 et un
  compilateur C pour les parsers manquants. Le highlighting est activé par FileType.
- Les LSP système sont explicitement activés et prioritaires dans le PATH:
  `clangd`, `rust-analyzer`, `gopls`, `ruff`. Mason installe seulement les serveurs
  absents; il peut notamment fournir `lua-language-server` et `pyright-langserver`.
  Node/npm est le runtime de Pyright, **pas son installation**.
- Si un téléchargement Mason échoue, installer le serveur correspondant par un
  autre moyen puis relancer Neovim. La configuration ne masque plus le serveur
  système derrière le PATH de Mason.
- Blink utilise son implémentation Lua; aucun binaire x86/Rust à télécharger pour
  la complétion. Telescope utilise sa configuration normale, sans fzf-native.
- Le module de presse-papiers distant est chargé sous tmux/SSH; en local Wayland,
  `wl-copy`/`wl-paste` fournissent le presse-papiers. Les requêtes OSC 52 dépendent
  des autorisations du terminal distant; leur support n'est pas garanti partout.

Ces corrections Neovim et tmux sont **partagées avec quattro**. Les fragments
shell partagés ne sont actuellement pas sourcés par le `.bashrc` Omarchy.

## Clavier, terminal et Plasma

Aucun layout `frmac`/`qwertyansi` n'est installé. Vérifier les choix existants dans
*Réglages système > Clavier*. Sur cette machine, Caps Lock est actuellement
configuré comme Échap; cela ne fournit pas une touche Compose.

Assigner une touche Compose libre dans les options clavier, puis redémarrer les
applications concernées (ou se reconnecter). Le comportement de `~/.XCompose`
dépend de l'application et de sa pile de saisie.

| Séquence | Résultat |
|---|---|
| Compose, Espace, n | Jvaxx |
| Compose, m, s | 😄 |
| Compose, Espace, Espace | — |

```bash
foot --check-config --config ~/.config/foot/foot.ini
fc-match 'JetBrainsMono Nerd Font'
# Optionnel: sélectionner foot dans les applications par défaut Plasma.
kwriteconfig6 --file kdeglobals --group General --key TerminalApplication foot
```

Foot conserve Ctrl+Shift+C/V, utilisables sur le clavier du MacBook. `TERM=foot`
permet à tmux de reconnaître le terminal; pour une machine SSH sans son terminfo:
`TERM=xterm-256color ssh <hôte>`. Les raccourcis interceptés par Plasma doivent
être ajustés dans les Réglages système; ils ne peuvent pas être forcés par tmux.

La configuration mpv locale sélectionne `vo=wlshm,x11` et `hwdec=no` pour éviter
un chemin de rendu GPU. Vérifier `mpv --vo=help`; les sorties logicielles ont des
limites de mise à l'échelle/HDR/shaders. Ne pas appliquer globalement des variables
Mesa/Qt de rendu logiciel: elles affecteraient toute la session KDE.

## Podman et lazydocker — opt-in

`podman-docker` fournit la compatibilité CLI `docker`, pas une configuration
complète de l'API Docker. Si lazydocker est utilisé:

```bash
systemctl --user enable --now podman.socket
DOCKER_HOST="unix://$XDG_RUNTIME_DIR/podman/podman.sock" lazydocker
```

Ne pas ajouter `sudo`, ne pas exposer le socket en TCP et ne pas activer le linger
sans besoin explicite. L'API donne accès aux conteneurs de l'utilisateur. Pour
rendre `DOCKER_HOST` persistant, l'exporter dans un fichier local `.bashrc.d/`.
`podman compose` utilise le fournisseur installé `podman-compose`; la compatibilité
Docker/Compose/lazydocker n'est pas parfaite. Préférer les images ARM64/multiarch;
aucune émulation x86/binfmt n'est installée.

## Sauvegarde, Git et tests

```bash
./sync.sh --dry-run
./sync.sh
./sync.sh --commit
python3 -B -m unittest discover -s tests -v
```

`sync.sh` refuse une source manquante plutôt que de produire une sauvegarde
partielle. Il conserve les liens vers le dépôt et ignore `.git`, `*.bak.*` et les
dossiers de staging. Les liens internes relatifs sont conservés; les liens
imbriqués absolus, externes ou cassés sont refusés. Une source de premier niveau
liée à un autre fichier/dossier est copiée comme contenu, pas comme lien externe.
Les propriétaires et attributs SELinux de l'ancien hôte ne sont pas importés.

Les anciennes versions restent à côté des destinations, ignorées par `.gitignore`.
Les examiner et les supprimer **manuellement** lorsqu'elles ne sont plus utiles;
elles peuvent contenir des réglages sensibles. En cas de souci de labels SELinux,
faire vérifier/relabeler les chemins concernés avec `restorecon`, pas désactiver
SELinux.

`STATE` et `packages.installed.txt` sont préparés avant publication. La liste RPM
utilise une requête DNF locale (`--installed --userinstalled`, sans réseau), avec
un paquet par ligne; un échec ne tronque pas l'ancienne liste.

`--commit` refuse un index Git déjà rempli et ne stage que les chemins du MANIFEST
et les métadonnées: ni `quattro/`, ni `macos/`, ni des scripts modifiés par ailleurs.
Un échec de commit est une vraie erreur; les fichiers et l'index restent disponibles
pour inspection. Aucun push automatique. Les opérations Asahi concurrentes sont
bloquées par un verrou local; cela ne coordonne pas les autres machines ni les
anciens scripts de quattro.

Les tests utilisent des homes/dépôts temporaires et des mocks DNF/sudo/Flatpak.
Ils n'installent rien et ne restaurent aucun fichier dans le vrai HOME.
