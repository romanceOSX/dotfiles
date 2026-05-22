#!/usr/bin/env sh

DOTFILES="$(cd "$(dirname "$0")" && pwd)"

link() {
    src="$1"
    dst="$2"
    mkdir -p "$(dirname "$dst")"
    ln -sf "$src" "$dst"
    echo "linked $dst"
}

link "$DOTFILES/.tmux.conf"              "$HOME/.tmux.conf"
link "$DOTFILES/bin/tmux-sessionizer"    "$HOME/.local/bin/tmux-sessionizer"
link "$DOTFILES/bin/tmux-launcher"       "$HOME/.local/bin/tmux-launcher"
