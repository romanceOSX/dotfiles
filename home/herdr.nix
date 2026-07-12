{ config, lib, herdr, ... }:
{
  home.packages = lib.optional (herdr != null) herdr;

  # Out-of-store symlink so the config is live-editable from the dots repo
  # without a home-manager switch. Edit home/herdr/config.toml directly.
  xdg.configFile."herdr".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/git/dots/home/herdr";
}
