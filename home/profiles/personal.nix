# Personal profile — the base role plus everything that only makes sense on my
# own (non-work) machines: the Taskwarrior/WingTask sync mesh, the herdr agent
# multiplexer, and the Alienware RGB
# wrappers. Modules that are hardware- or host-specific still gate themselves
# internally (isAlien / isWSL / stdenv.isDarwin), so importing them everywhere
# is a no-op where they don't apply.
#
# This is the default profile for all personal hosts (osx, wsl, debian, alien,
# pi). The work host also composes this profile and then layers the private
# work module on top — see flake.nix.
{ ... }:
{
  imports = [
    ./base.nix
    ../secrets.nix
    ../tsvc.nix
    ../system-proxy.nix
    ../taskwarrior.nix
    ../herdr.nix
    ../alien.nix
    ../devtunnel.nix
    ../opencode.nix
  ];
}
