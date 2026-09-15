# Sauvegarde / restauration macOS

Même principe que Quattro : `MANIFEST`, `home/`, `shared/home/`, deux scripts.
Compatible avec le Bash 3.2 et le rsync fournis par macOS. Pas de bootstrap,
services automatiques, sudo, installation de paquets ou changement de SIP.

## Restaurer (le dépôt fait foi)

```bash
cd ~/Documents/MaConfig
git pull --ff-only
./macos/restore.sh --dry-run
./macos/restore.sh             # confirmation ; --yes pour l'omettre
```

Si l'accès SSH à GitHub n'est pas encore configuré, récupérer la version publique
sans changer `origin` :

```bash
git fetch https://github.com/Jvaxx/MaConfig.git master
git merge --ff-only FETCH_HEAD
```

Cela permet de lire le dépôt, pas de pousser : configurer ensuite une clé SSH
GitHub ou une authentification HTTPS pour `git push`.

Les fichiers **et dossiers** existants sont déplacés à côté de l'original en
`*.bak.<date>.<pid>` avant remplacement. Les anciens fichiers absents du dépôt
ne restent donc pas dans les dossiers restaurés. Les liens vers le dépôt sont
conservés ; les autres liens (même cassés) sont sauvegardés puis remplacés par
une copie. Aucune sauvegarde n'est effacée automatiquement.

Sur cette migration, les versions GitHub de Zsh, Ghostty, skhd, yabai et des
configs partagées ont priorité sur les versions locales. Les nouveaux fichiers
(`.zprofile`, `.gitconfig`, Karabiner, inventaire Homebrew) viennent de ce Mac.
Zsh a seulement été adapté pour les chemins `$HOME`, les outils optionnels et
les overrides locaux. Faire **restore avant sync** sur une machine en retard,
sinon ses anciennes configs écraseraient les versions du dépôt (y compris shared).
Les scripts ne font ni pull ni push et ne résolvent pas les conflits Git.

## Sauvegarder après une modification

```bash
./macos/sync.sh --dry-run
./macos/sync.sh               # $HOME -> dépôt + Brewfile + STATE
# Relire les changements, particulièrement ceux dans shared/ :
git diff HEAD -- macos shared
./macos/sync.sh --commit      # optionnel ; commit limité à macos et shared/home
git push
```

Une source locale absente est signalée et sa dernière sauvegarde conservée.
Pour retirer une config volontairement, retirer aussi son entrée du MANIFEST et
sa copie du dépôt. Les dossiers sont recopiés sans `.git`, `.DS_Store` ou
`*.bak.*`. Les liens internes aux dossiers sont conservés : vérifier qu'ils sont
portables avant de commiter. Pas de synchronisation concurrente.

Ajouter un chemin relatif à `$HOME` au `MANIFEST` (espaces acceptés), puis sync.
`shared:` partage les modifications avec Linux : Neovim, Starship et tmux.
Les fichiers Git restent locaux : le fichier partagé appelle `/usr/bin/gh`,
inexistant sur macOS. Les fragments Bash et XCompose Linux ne sont pas installés.
Les secrets et hooks propres à ce Mac peuvent aller dans `~/.zshrc.local` ou
`~/.zprofile.local`, chargés mais jamais sauvegardés.

## Paquets : réinstallation explicite

Installer les outils de développement Apple (`xcode-select --install`) et
[Homebrew](https://brew.sh), puis :

```bash
brew bundle check --file=macos/Brewfile
brew bundle install --file=macos/Brewfile   # relire la liste avant !
# Neovim partagé exige >= 0.12 (vim.pack), fourni ici via bob :
bob install nightly
bob use nightly
nvim --version
# Pour compiler les parsers Treesitter :
brew install tree-sitter
# tmux n'était pas installé au moment de la migration :
brew install tmux                         # si utilisé
```

`Brewfile` est l'inventaire généré par `brew bundle dump --no-vscode`, pas une
liste minimale, ni un verrouillage de versions. Il peut aussi contenir les outils
npm reconnus par Homebrew Bundle. Son export ne lance ni installation ni upgrade.
Sur ce Mac, Homebrew signale un cycle `libtiff` / `webp` dans ses métadonnées
locales, mais l'export réussit. Aucun paquet n'a été désinstallé pour le corriger.
Les applications hors Homebrew, environnements conda/pipx et binaires installés
à la main restent à réinstaller séparément (notamment Zen, VS Code, LM Studio,
yabai/skhd actuellement présents hors de l'inventaire Homebrew).

## Activer / vérifier

- Ouvrir un nouveau terminal ; `.zprofile` initialise Homebrew et `.zshrc` Zsh.
  Si nécessaire : `conda init zsh` après l'installation de Miniforge.
- Ouvrir Neovim : premier lancement avec réseau pour les plugins et outils.
  `:checkhealth` pour vérifier. Le presse-papiers local macOS utilise `pbcopy`.
- Ghostty utilise `~/.config/ghostty/`. Son autre fichier possible,
  `~/Library/Application Support/com.mitchellh.ghostty/config`, était vide lors
  de la migration ; s'il contient des overrides, les vérifier séparément.
- Installer yabai/skhd selon leur documentation et accorder les autorisations
  Accessibilité. Ensuite, explicitement : `yabai --start-service` et
  `skhd --start-service` (ou `--restart-service` s'ils tournent déjà).
  La configuration yabai versionnée appelle `sudo yabai --load-sa` : le scripting
  addition, SIP et sudoers se configurent **manuellement** selon la version de
  macOS. Le vieux `saconfig.py` n'est jamais exécuté par nos scripts.
- Karabiner : ouvrir l'app et accorder les autorisations demandées. La config
  sauvegardée remappe Fn/Ctrl, Caps/Escape, Cmd/Alt droits et ajoute `<` / `>`.
  L'ancien `com.user.keymapping.plist` est archivé dans `old/`, **pas installé** :
  il ferait doublon avec Karabiner. Ne pas activer les deux.
- Les services ne sont pas relancés par restore, mais certaines apps peuvent
  détecter les changements de config automatiquement.

## Réglages système (séparés)

```bash
./macos/defaults.sh --dry-run
./macos/defaults.sh            # optionnel : animations et répétition clavier
```

Ce sont les réglages explicites des anciennes notes, **pas un export des
préférences actuelles**. Ce script ne sauvegarde pas les anciennes valeurs et
n'est jamais appelé par sync/restore. Réouvrir la session après application.
Les réglages Finder, Dock, trackpad (glissement à trois doigts), permissions,
profils navigateur, clés SSH et secrets restent manuels. On ne sauvegarde pas
`~/Library/Preferences` ou `~/Library/Application Support` en bloc. Les anciennes
notes sont dans `old/` pour référence ; désactiver les mises à jour n'est pas
une étape de restauration.

## Tests sans toucher à la machine

```bash
python3 -B -m unittest discover -s macos/tests -v
```

Les tests utilisent un HOME et un dépôt temporaires, ainsi qu'un faux Homebrew.
