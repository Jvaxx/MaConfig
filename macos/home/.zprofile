# Homebrew (Apple Silicon ou Intel).
if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
fi
export PATH="$PATH:/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
[[ ! -r "$HOME/.zprofile.local" ]] || source "$HOME/.zprofile.local"
