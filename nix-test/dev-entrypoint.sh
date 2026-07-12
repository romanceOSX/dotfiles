#!/usr/bin/env bash
# Runtime activation for the dev-loop image.
#   /nix  — persistent named volume: the store (toolchain) survives across runs.
#   /src  — your bind-mounted working tree (read-only).
# We sync /src into a path flake (no .git) so Nix sees untracked files, rewrite
# the linux host's system double to this machine's arch, then `switch`.
set -u

. "$HOME/.nix-profile/etc/profile.d/nix.sh" 2>/dev/null || true

HM_HOST="${HM_HOST:-debian}"

if [ -d /src ]; then
  echo ">> syncing /src -> ~/git/dots (path flake, sans .git)"
  mkdir -p ~/git/dots
  rsync -a --delete \
    --exclude='.git' --exclude='result' --exclude='result-*' \
    --exclude='.direnv' --exclude='local.nix' \
    /src/ ~/git/dots/
  sed -i "s/x86_64-linux/$(uname -m)-linux/g" ~/git/dots/flake.nix

  # Drive the flake's machine-local identity from THIS container's user, so the
  # same image tests any username (dev.sh's 2nd arg). local.nix is gitignored and
  # excluded from the rsync above, so this never leaks back to the host tree.
  echo ">> writing local.nix for ${USER} (${HOME})"
  printf '{ username = "%s"; homeDirectory = "%s"; }\n' "$USER" "$HOME" \
    > ~/git/dots/local.nix
fi

echo ">> home-manager switch --flake .#${HM_HOST}   (store cached in the /nix volume)"
if ! ( cd ~/git/dots && nix run home-manager/master -- switch -b backup --flake ".#${HM_HOST}" ); then
  echo "!! switch failed — dropping into bash so you can inspect" >&2
  exec bash -l
fi

# Load the Home Manager session env, then drop into the themed zsh.
for f in \
  "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" \
  "$HOME/.local/state/nix/profiles/home-manager/home-path/etc/profile.d/hm-session-vars.sh"; do
  [ -e "$f" ] && . "$f"
done
export PATH="$HOME/.nix-profile/bin:$HOME/.local/state/nix/profiles/home-manager/home-path/bin:$PATH"

echo ">> activated. (try Ctrl+R, the prompt, \`y\`, tmux …)"
command -v zsh >/dev/null 2>&1 && exec zsh -l || exec bash -l
