#!/usr/bin/env sh
set -e

command -v stow >/dev/null 2>&1 || { echo "stow is required: brew install stow"; exit 1; }

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
stow --target="$HOME" --dir="$DOTFILES" .
echo "dotfiles linked"
