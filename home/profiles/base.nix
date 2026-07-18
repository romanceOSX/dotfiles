# Base profile — the universal foundation every host gets, and the profile used
# by the **minimal** role (IoT/appliance tier, e.g. the Pi).
#
# This is the "role" every machine shares: shell, core CLI/editor packages,
# per-tool program configs (incl. btop monitoring), tmux, and the shell utility
# scripts. It carries nothing personal-only (no task-sync mesh, no herdr, no
# Alienware RGB) so it can also underpin a lean/work configuration that doesn't
# want that surface. `client`/`server` roles layer the personal surface on top
# via ./personal.nix. See the `mkHome`/role composition in flake.nix.
{ ... }:
{
  imports = [
    ../packages.nix
    ../shell.nix
    ../programs.nix
    ../direnv.nix
    ../tmux.nix
    ../scripts.nix
  ];

  # Let Home Manager manage itself and the XDG base dirs (exports XDG_CONFIG_HOME
  # etc., so tools that respect XDG — including lazygit — find ~/.config).
  programs.home-manager.enable = true;
  xdg.enable = true;

  # Don't change this after first activation unless you read the HM release notes.
  home.stateVersion = "24.11";
}
