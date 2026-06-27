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

  # ---------------------------------------------------------------------------
  # Matrix messaging services — alien host only.
  #
  # Three lightweight systemd user services that form the backend for the
  # WeeChat + Matrix TUI messaging stack (see home/messaging.nix, docs/messaging.md):
  #
  #   matrix-conduit  — Conduit homeserver (listens on localhost:6167)
  #   mautrix-whatsapp — bridge to WhatsApp Web (localhost:29318)
  #   mautrix-discord  — bridge to Discord API  (localhost:29334)
  #
  # These services are NOT added to default.target, so they only run when
  # explicitly started via `messaging-stack start`. The setup script handles
  # first-time config generation and then starts them. Runtime state lives in
  # ~/.local/share/messaging/{conduit,whatsapp,discord}/ (not managed by Nix).
  #
  # Run `loginctl enable-linger romance` once so user services survive logout.
  # ---------------------------------------------------------------------------
  systemd.user.services.matrix-conduit = lib.mkIf isAlien {
    Unit = {
      Description = "Conduit Matrix homeserver";
      After = [ "network.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.matrix-conduit}/bin/conduit";
      Environment = [
        "CONDUIT_CONFIG=%h/.local/share/messaging/conduit/conduit.toml"
      ];
      WorkingDirectory = "%h/.local/share/messaging/conduit";
      Restart = "on-failure";
      RestartSec = "5s";
    };
    # No Install.WantedBy — only started explicitly by messaging-stack.
  };

  systemd.user.services.mautrix-whatsapp = lib.mkIf isAlien {
    Unit = {
      Description = "mautrix-whatsapp bridge";
      After = [ "network.target" "matrix-conduit.service" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.mautrix-whatsapp}/bin/mautrix-whatsapp --config %h/.local/share/messaging/whatsapp/config.yaml";
      WorkingDirectory = "%h/.local/share/messaging/whatsapp";
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };

  systemd.user.services.mautrix-discord = lib.mkIf isAlien {
    Unit = {
      Description = "mautrix-discord bridge";
      After = [ "network.target" "matrix-conduit.service" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.mautrix-discord}/bin/mautrix-discord --config %h/.local/share/messaging/discord/config.yaml";
      WorkingDirectory = "%h/.local/share/messaging/discord";
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };

  # Colima auto-start — Linux/alien only.
  # Runs the colima VM (QEMU+KVM) as a user service so docker is always
  # available without a manual `colima start`.  Requires the user to be in
  # the `kvm` group (done via `usermod -aG kvm romance`).
  systemd.user.services.colima = lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "Colima container runtime";
      After = [ "network.target" ];
    };
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.colima}/bin/colima start";
      ExecStop  = "${pkgs.colima}/bin/colima stop";
      Environment = [
        "PATH=${pkgs.docker-client}/bin:${pkgs.colima}/bin:/usr/local/bin:/usr/bin:/bin"
      ];
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
