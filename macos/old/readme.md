# Configuration de macOS

## Système et Prérequis

**Installation du gestionnaire de paquets**
- Installation de Homebrew via le script officiel.

**Suspension des mises à jour macOS**
Désactiver le SIP pour désactiver le daemon de maj.
1. Redémarrer en mode Recovery.
2. Ouvrir le terminal et désactiver le SIP : `csrutil disable`
3. Redémarrer sur l'OS et désactiver le service de mise à jour :
   ```bash
   sudo launchctl disable system/com.apple.softwareupdated
   ```
4. Redémarrer en mode Recovery pour réactiver le SIP : `csrutil enable`

## Réglages de l'Interface

**Préférences Générales**
- Desktop et Docks : À compléter.
- Control Center : Paramètres modifiés selon préférences.
- Finder : Modifications de bon sens (affichage des extensions, chemins, etc.).

**Périphériques (Trackpad et Clavier)**
- Trackpad et Clavier : À compléter.
- Accessibilité : Activation du glissement à trois doigts (Three fingers drag).

## Optimisations en Ligne de Commande

**Réduction des animations système**
```bash
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock autohide-time-modifier -float 0
defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false
defaults write -g QLPanelAnimationDuration -float 0
defaults write com.apple.dock launchanim -bool false
defaults write com.apple.dock expose-animation-duration -float 0
killall Finder && killall Dock
```

**Accélération de la réactivité du clavier**
```bash
defaults write -g KeyRepeat -int 1
defaults write -g InitialKeyRepeat -int 10
defaults write -g ApplePressAndHoldEnabled -bool false
```

## Terminal et Environnement Shell

**Émulateur de Terminal et Éditeur**
- Installation de Ghostty et de Bob (gestionnaire de versions pour Neovim) :
  ```bash
  brew install --cask ghostty
  brew install bob
  bob install nightly
  bob use nightly
  ```
- Configuration Ghostty : Voir dotfiles sur GitHub.

**Configuration Zsh**
- Création du fichier : `touch ~/.zshrc`
- Ajout d'un paquet Homebrew pour la coloration syntaxique zsh.
- Starship (Prompt) :
  ```bash
  brew install starship
  ```
  Ajouter `eval "$(starship init zsh)"` dans le `.zshrc` et utiliser le même `starship.toml` que sur OmArchy.
- Fichier Zshrc complet : Voir dotfiles sur GitHub.

## Gestionnaire de Fenêtres (Tiling)

**Yabai et Skhd**
- Installation et démarrage de skhd :
  ```bash
  brew install asmvik/formulae/skhd
  skhd --start-service
  ```
- Yabai : Nécessite une désactivation partielle du SIP pour le scripting addition (suivre la documentation officielle).
- Installation de Yabai : Avec le scripting addition (prévoir quelques manipulations spécifiques selon la doc et quelques galères).

## Applications et Utilitaires

**Casks et Formulae Homebrew**
- `aldente` : Gestion de la charge de la batterie.
- `localsend` : Partage réseau local.
- `vlc` : Lecteur multimédia.
- `maccy` : Gestionnaire de presse-papiers.
- `visual-studio-code` : Éditeur de code.
- `btop` : Moniteur de ressources.
- `lm-studio` : Inférence LLM en local.

**Navigateur Zen**
- Installation via le site officiel.
- Raccourcis : PiP sur `Ctrl + Shift + %`, remplacement de tous les raccourcis `Cmd` par `Ctrl`.
- Paramètres : Zen mod (Ghost tab) activé, Privacy sur Strict.
- Extensions : Dark Reader, YouTube No Translation, UBO, SponsorBlock, Tampermonkey + VAFT.
- Extensions custom : Bypass Paywall Clean, TwitchNoSub.

## Configuration Avancée et Réseau

**Mappage Clavier Personnalisé**
- Échange de la touche Cmd droite et Alt droite.
- Placer le fichier `com.user.keymapping.plist` dans `/Users/jvz/Library/LaunchAgents/`.

**SSH et Réseau**
- Clés SSH et alias : Installation pour le PC fixe, le Raspberry Pi 5 et GitHub.
