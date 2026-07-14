# Portainer CE — the docker management web UI.
#
# Portainer has no nixpkgs package; it ships only as a docker image and runs as
# a container. So instead of a package we install a launcher (.local/bin/portainer,
# `portainer start|stop|status|update`) that drives `docker run portainer/portainer-ce`.
#
# It only makes sense where a docker daemon is present, so it's gated to the same
# hosts that get the docker CLI (see home/packages.nix): macOS (colima) or a Linux
# host that opts into docker via `enableDocker` in flake.nix. On every other host
# this module is a no-op.
{ pkgs, lib, enableDocker ? false, ... }:
let
  dockerHost = pkgs.stdenv.isDarwin || (pkgs.stdenv.isLinux && enableDocker);
in
{
  home.file = lib.mkIf dockerHost {
    ".local/bin/portainer" = {
      source = ../.local/bin/portainer;
      executable = true;
    };
  };
}
