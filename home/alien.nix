{ pkgs, lib, isAlien ? false, ... }:
let
  # Alienware (Dell G Series) RGB control wrappers — alien host only.
  #
  # OpenRGB itself is intentionally NOT a nix package: it's installed from
  # Ubuntu's apt (`/usr/bin/openrgb`, universe repo) because it needs the
  # system udev rules + hidraw access that ship with the distro package. These
  # wrappers just drive that binary, so they only make sense where it exists —
  # hence the isAlien gate from flake.nix.
  #
  # Root is required: the device is /dev/hidraw0 (root-owned), and the OpenRGB
  # `uaccess` udev rule only grants the *active graphical seat* user, not
  # romance over SSH or at boot. sudo is passwordless on this host.
  openrgb = "/usr/bin/openrgb";
  device = "Dell G Series LED Controller"; # match by name; index can shift

  # Turn the lighting fully off — static mode, black, across all 14 zones.
  rgbOff = pkgs.writeShellScriptBin "rom-alien-rgb-off" ''
    set -euo pipefail
    exec sudo ${openrgb} --device ${lib.escapeShellArg device} --mode static --color 000000
  '';

  # Turn the lighting back on. No arg → Rainbow Wave. A mode keyword (rainbow,
  # spectrum, breathing, static) or a raw RRGGBB hex also works:
  #   rom-alien-rgb-on            # Rainbow Wave
  #   rom-alien-rgb-on spectrum   # Spectrum Cycle
  #   rom-alien-rgb-on FF0000     # solid red
  rgbOn = pkgs.writeShellScriptBin "rom-alien-rgb-on" ''
    set -euo pipefail
    arg="''${1:-rainbow}"
    case "$arg" in
      rainbow|wave)     exec sudo ${openrgb} --device ${lib.escapeShellArg device} --mode "Rainbow Wave" ;;
      spectrum|cycle)   exec sudo ${openrgb} --device ${lib.escapeShellArg device} --mode "Spectrum Cycle" ;;
      breathing|breath) exec sudo ${openrgb} --device ${lib.escapeShellArg device} --mode "Breathing" ;;
      static|white)     exec sudo ${openrgb} --device ${lib.escapeShellArg device} --mode static --color FFFFFF ;;
      [0-9A-Fa-f]*)     exec sudo ${openrgb} --device ${lib.escapeShellArg device} --mode static --color "$arg" ;;
      *) echo "rom-alien-rgb-on: unknown arg '$arg' (try: rainbow|spectrum|breathing|static|RRGGBB)" >&2; exit 2 ;;
    esac
  '';

  # Show what OpenRGB sees (device list, modes, zones).
  rgbStatus = pkgs.writeShellScriptBin "rom-alien-rgb-status" ''
    exec sudo ${openrgb} --list-devices
  '';
in
{
  home.packages = lib.optionals isAlien [ rgbOff rgbOn rgbStatus ];

  # No Colima service on Linux — Colima is a macOS Docker runtime (Lima VM).
  # Linux hosts (alien) run native dockerd, managed by the distro's system
  # service (e.g. `systemctl enable --now docker` on Ubuntu), not Home Manager.
  # See home/packages.nix, where `colima` is gated to Darwin.
}
