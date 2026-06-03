{ ... }:
{
  imports = [
    ./packages.nix
    ./shell.nix
    ./programs.nix
    ./tmux.nix
    ./scripts.nix
  ];

  # Let Home Manager manage itself and the XDG base dirs (exports XDG_CONFIG_HOME
  # etc., so tools that respect XDG — including lazygit — find ~/.config).
  programs.home-manager.enable = true;
  xdg.enable = true;

  # Don't change this after first activation unless you read the HM release notes.
  home.stateVersion = "24.11";
}
