#!/usr/bin/env bash
# Load Nix + the Home Manager session environment, then drop into the themed
# zsh (falls back to bash if zsh somehow isn't on PATH). This mirrors what a
# login shell would do after a real `home-manager switch`.

# Nix itself
[ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ] && . "$HOME/.nix-profile/etc/profile.d/nix.sh"

# Home Manager session vars (path varies a little by HM version)
for f in \
  "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" \
  "$HOME/.local/state/nix/profiles/home-manager/home-path/etc/profile.d/hm-session-vars.sh"; do
  [ -e "$f" ] && . "$f"
done

# Make sure the HM-provided binaries (incl. zsh) are reachable.
export PATH="$HOME/.nix-profile/bin:$HOME/.local/state/nix/profiles/home-manager/home-path/bin:$PATH"

if command -v zsh >/dev/null 2>&1; then
  exec zsh -l
else
  echo "note: zsh not found on PATH; starting bash. Inspect ~/.config and \`home-manager generations\`." >&2
  exec bash -l
fi
