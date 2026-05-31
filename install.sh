#!/usr/bin/env sh
set -e

command -v stow >/dev/null 2>&1 || { echo "stow is required: brew install stow"; exit 1; }

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
stow --target="$HOME" --dir="$DOTFILES" .
echo "dotfiles linked"

# zsh plugins (cloned, not stowed)
FZF_TAB="$HOME/.config/zsh/plugins/fzf-tab"
if [ ! -d "$FZF_TAB" ]; then
    git clone --depth 1 https://github.com/Aloxaf/fzf-tab "$FZF_TAB"
    echo "fzf-tab installed"
fi
