# direnv + nix-direnv — per-directory environments and fast .env loading.
#
# Why this exists: editing a secret / API key should not require a Home Manager
# rebuild. direnv sources a machine-local, gitignored ./.env the instant you cd
# into a repo (via `dotenv_if_exists` in .envrc), so credentials change without
# any Nix evaluation. nix-direnv adds the `use flake` helper + a persistent
# eval cache so entering a flake dir doesn't re-evaluate every time.
#
# The shell hook is wired automatically for whichever shells are enabled.
{ ... }:
{
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;

    # Shell init hooks — Home Manager injects `eval "$(direnv hook <shell>)"`.
    enableZshIntegration = true;
    enableBashIntegration = true;
    enableFishIntegration = true;
  };
}
