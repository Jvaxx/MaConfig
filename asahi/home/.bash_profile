# ~/.bash_profile — Fedora Asahi Remix.
# Login shells: get the user PATH bits Fedora expects, then defer to .bashrc.

[[ -f ~/.bashrc ]] && . ~/.bashrc

if [ -d "$HOME/.local/bin" ]; then
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) PATH="$HOME/.local/bin:$PATH" ;;
  esac
fi
export PATH
