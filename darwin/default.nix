# nix-darwin system module for the "osx" host.
#
# Scope is deliberately narrow: the user environment is still managed by
# standalone Home Manager (`home-manager switch --flake .#osx`). nix-darwin here
# owns only the system layer Home Manager can't express on macOS — the root
# tailscaled LaunchDaemon. `nix.enable = false` keeps nix-darwin from touching
# the existing official multi-user nix install.
{ pkgs, ... }:
{
  nix.enable = false;
  system.stateVersion = 6;
  system.primaryUser = "romance";
  nixpkgs.hostPlatform = "aarch64-darwin";

  # Tailscale node agent (root daemon), via nix-darwin's official module.
  #
  # Replaces the old ~/.local/bin/install-tailscaled-daemon hand-rolled plist,
  # which faced an unwinnable tradeoff:
  #   * point at ~/.nix-profile/bin/tailscaled — survives `home-manager switch`,
  #     but a root LaunchDaemon can't traverse the user-home symlink chain at
  #     boot, so it died early with EX_CONFIG (78) before even logging; or
  #   * point at /nix/store/...-tailscale-<ver>/bin/tailscaled — boots fine, but
  #     the next profile GC/upgrade removes that path and the daemon breaks.
  #
  # The module pins tailscaled in the system profile (a gcroot, so never
  # collected) and regenerates the LaunchDaemon plist with the current store
  # path on every `darwin-rebuild switch`. It also wires up the MagicDNS
  # resolver (/etc/resolver/ts.net) and adds the `tailscale` CLI to system
  # packages. The daemon uses tailscaled's default macOS state dir
  # (/Library/Tailscale), so authenticate once after the first switch:
  #   sudo tailscale up
  services.tailscale.enable = true;

  # mtr without sudo (macOS only).
  #
  # mtr's helper `mtr-packet` needs raw ICMP sockets. On macOS those require
  # root, and unlike Linux this build has no unprivileged fallback (Linux's
  # mtr-packet uses IPPROTO_ICMP datagram sockets, permitted by a wide
  # net.ipv4.ping_group_range — so the Linux hosts need none of this). The
  # Nix-store binary can't carry the setuid bit (read-only store), so copy it
  # to a stable root-owned setuid location on every `darwin-rebuild switch`,
  # keeping it in lockstep with the packaged mtr. Home Manager points
  # MTR_PACKET at this copy (see home/shell.nix). Referencing ${pkgs.mtr} here
  # also pins it in the system closure (a gcroot), so the source never gets
  # collected out from under the copy.
  system.activationScripts.extraActivation.text = ''
    install -d -m 0755 /usr/local/bin
    install -m 4555 -o root -g wheel \
      ${pkgs.mtr}/bin/mtr-packet /usr/local/bin/mtr-packet
  '';
}
