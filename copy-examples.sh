#!/usr/bin/env sh
set -eu

# copy-examples.sh — materialize machine-local config from the tracked *.example
# templates. These files are deliberately NOT managed by nix/home-manager (each
# host edits its own copy), so this is the one-shot convenience that drops each
# template at the location its consumer actually reads.
#
# Safe to re-run: existing destinations are left untouched unless you pass
# -f / --force. Run it from anywhere — the repo dir is derived from this script.
#
#   ./copy-examples.sh           # create any missing config from its template
#   ./copy-examples.sh --force   # overwrite existing config from the template

DOTFILES="$(cd "$(dirname "$0")" && pwd)"

FORCE=0
case "${1:-}" in
    -f | --force) FORCE=1 ;;
    "") ;;
    *) echo "usage: $0 [-f|--force]" >&2; exit 2 ;;
esac

# Map of <template (relative to repo)> -> <destination>. A template's location
# is NOT derivable from its name (local.nix lives in the repo; the sessionizer
# config lives under ~/.config), so destinations are explicit. Add new templates
# here. Parent directories are created as needed.
MAP="
local.nix.example|$DOTFILES/local.nix
home/tmux-sessionizer.toml.example|$HOME/.config/tmux/sessionizer.toml
"

echo "$MAP" | while IFS='|' read -r rel dest; do
    [ -n "$rel" ] || continue
    src="$DOTFILES/$rel"
    if [ ! -f "$src" ]; then
        printf 'warning: template missing: %s\n' "$rel" >&2
        continue
    fi
    if [ -e "$dest" ] && [ "$FORCE" -ne 1 ]; then
        printf 'skip    %s (exists; --force to overwrite)\n' "$dest"
        continue
    fi
    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
    printf 'copied  %s -> %s\n' "$rel" "$dest"
done

# Heads-up if a tracked *.example has no destination in MAP above, so new
# templates don't silently go un-copied.
known=$(printf '%s\n' "$MAP" | sed -n 's/|.*//p')
git -C "$DOTFILES" ls-files '*.example' | while read -r f; do
    printf '%s\n' "$known" | grep -qxF "$f" || \
        printf 'note: %s has no destination in copy-examples.sh — add it to MAP\n' "$f" >&2
done
