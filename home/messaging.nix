{ config, lib, pkgs, isAlien ? false, ... }:
let
  # Only the machines that actually drive the TUI get the (heavy, Python-laden)
  # matrix-enabled WeeChat: this Mac, and the always-on `alien` node. The Pi, WSL,
  # and the other Linux hosts skip it so they don't compile matrix-nio + olm from
  # source with no binary cache.
  installWeechat = pkgs.stdenv.isDarwin || isAlien;

  # weechat-matrix (and its matrix-nio dependency) is marked broken on Python 3.13
  # in nixpkgs (the `future` dependency is disabled there). Pin the WeeChat python
  # plugin *and* the script to Python 3.12, where the whole chain builds. Building
  # the script inside the 3.12 package set keeps its ABI in lockstep with the
  # plugin the wrapper enables.
  pyPkgs = pkgs.python312Packages;
  weechat-matrix-py312 = pyPkgs.callPackage
    (pkgs.path + "/pkgs/applications/networking/irc/weechat/scripts/weechat-matrix")
    { };
  weechatUnwrapped312 = pkgs.weechat-unwrapped.override { python3Packages = pyPkgs; };

  weechatMatrix = pkgs.wrapWeechat weechatUnwrapped312 {
    configure = { availablePlugins, ... }: {
      # Enable only the python plugin — the wrapper otherwise pulls every plugin,
      # forcing evaluation of php (not built on darwin) and breaking eval.
      plugins = [ availablePlugins.python ];
      scripts = [ weechat-matrix-py312 ];
    };
  };
in
{
  # ---------------------------------------------------------------------------
  # Unified TUI messaging: WeeChat + Matrix
  #
  # WeeChat is the single terminal client. It speaks the Matrix protocol (via the
  # weechat-matrix Python script) to a local Conduit homeserver, which in turn is
  # bridged to WhatsApp and Discord through the mautrix-* bridges. No AI, no cloud
  # processing — every component runs locally (or on the `alien` node).
  #
  #   WeeChat (vim TUI) ──Matrix──► Conduit ──► mautrix-whatsapp ──► WhatsApp Web
  #                                         └──► mautrix-discord  ──► Discord API
  #
  # The Conduit + bridge containers are managed out-of-band by `messaging-stack`
  # (see .local/bin/messaging-stack) because they need a docker daemon (Colima on
  # macOS, native on Linux) and runtime token generation. Nix only provides the
  # WeeChat client, the compose file, and the config templates.
  # ---------------------------------------------------------------------------

  home.packages = lib.optional installWeechat weechatMatrix;

  # Compose file + bridge/homeserver config templates. These live under
  # ~/.config/messaging as read-only store symlinks; `messaging-stack` reads them,
  # substitutes the runtime tokens, and writes the rendered configs into the
  # gitignored data dir at ~/.local/share/messaging. Installed on every host so
  # the `messaging-stack` script (and its alien delegation) always finds them.
  xdg.configFile."messaging/docker-compose.yml".source = ./messaging/docker-compose.yml;
  xdg.configFile."messaging/conduit.toml.template".source = ./messaging/conduit.toml.template;
  xdg.configFile."messaging/whatsapp.yaml.template".source = ./messaging/whatsapp.yaml.template;
  xdg.configFile."messaging/discord.yaml.template".source = ./messaging/discord.yaml.template;
}
