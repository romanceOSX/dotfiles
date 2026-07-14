# Base profile — the universal foundation every host gets, regardless of role.
#
# This is the "role" every machine shares: shell, editor/tooling packages,
# per-tool program configs, tmux, and the shell utility scripts. It carries
# nothing personal-only (no task-sync mesh, no herdr, no
# Alienware RGB) so it can also underpin an isolated work configuration that
# doesn't want that surface. See ./personal.nix for the personal role, and the
# `mkHome` composition in flake.nix.
{ ... }:
{
  imports = [
    ../packages.nix
    ../shell.nix
    ../programs.nix
    ../direnv.nix
    ../tmux.nix
    ../scripts.nix
    ../portainer.nix
  ];

  # Let Home Manager manage itself and the XDG base dirs (exports XDG_CONFIG_HOME
  # etc., so tools that respect XDG — including lazygit — find ~/.config).
  programs.home-manager.enable = true;
  xdg.enable = true;

  # Don't change this after first activation unless you read the HM release notes.
  home.stateVersion = "24.11";
}
