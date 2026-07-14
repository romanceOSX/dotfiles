# Portainer CE — the docker management web UI.
#
# Portainer has no nixpkgs package; it ships only as a docker image and runs as
# a container. So instead of a package we install a launcher (.local/bin/portainer,
# `portainer start|stop|status|update`) that drives `docker run portainer/portainer-ce`.
#
# Gated to Linux hosts flagged `isServer` in flake.nix (the boxes that run
# dockerd). macOS is excluded on purpose — those machines almost never run
# containers, and Portainer is for managing the always-on server daemons. No-op
# on every other host, including client-only Linux/WSL boxes.
{ pkgs, lib, isServer ? false, ... }:
let
  serverHost = pkgs.stdenv.isLinux && isServer;
in
{
  home.file = lib.mkIf serverHost {
    ".local/bin/portainer" = {
      source = ../.local/bin/portainer;
      executable = true;
    };
  };
}
