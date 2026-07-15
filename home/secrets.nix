# sops-nix secrets — decrypt host credentials at activation.
#
# The encrypted values live in ../secrets.yaml (committed, encrypted to each
# host's SSH ed25519 key via .sops.yaml). Each host in the mesh decrypts the
# *same* ciphertext with its own key, so they're automatically consistent (this
# replaced the old scheme of hand-copying values into every host's local.nix).
#
# Two independent consumers gate this module — the sops base config (age key +
# default file) turns on if *either* wants a secret:
#   - WingTask (Taskwarrior sync): opt-in via `wingtaskServerUrl` in local.nix.
#     The non-secret URL doubles as the "is sync configured here?" build gate.
#   - tsvc (Tailscale per-service sidecars, home/tsvc.nix): Linux servers only.
#     Needs the Tailscale OAuth client secret to mint ephemeral auth keys.
{ config, lib, pkgs, wingtaskServerUrl ? null, role ? "client", ... }:
let
  wingtaskConfigured = wingtaskServerUrl != null;
  # Only Linux `server` hosts run the docker services fronted by tsvc; those are
  # the only boxes that need the Tailscale OAuth secret. Keep this gate byte-for-
  # byte in sync with home/tsvc.nix's `enable`.
  tsvcEnabled = pkgs.stdenv.isLinux && role == "server";
  anySecret = wingtaskConfigured || tsvcEnabled;
in
lib.mkIf anySecret {
  sops = {
    defaultSopsFile = ../secrets.yaml;

    # Derive the age identity from this host's SSH ed25519 private key (the same
    # key already used for git/ssh). No separate age key to distribute.
    age.sshKeyPaths = [ "${config.home.homeDirectory}/.ssh/id_ed25519" ];

    secrets = lib.mkMerge [
      (lib.mkIf wingtaskConfigured {
        wingtask_client_id = { };
        wingtask_encryption_secret = { };
      })
      (lib.mkIf tsvcEnabled {
        # Tailscale OAuth client secret — scope `auth_keys`, tag `tag:svc`.
        # tsvc reads the rendered file (0400) to bring up service sidecars; the
        # OAuth secret mints ephemeral, non-expiring keys, so new services need
        # no key rotation. See home/tsvc.nix.
        tailscale_svc_oauth = { };
      })
    ];

    # Rendered (0400) at activation to
    #   ~/.config/sops-nix/secrets/rendered/taskrc-sync
    # and pulled into taskrc via `include` (see home/taskwarrior.nix), so the
    # decrypted secret never lands in the world-readable generated taskrc.
    templates = lib.mkIf wingtaskConfigured {
      "taskrc-sync".content = ''
        sync.server.url=${wingtaskServerUrl}
        sync.server.client_id=${config.sops.placeholder.wingtask_client_id}
        sync.encryption_secret=${config.sops.placeholder.wingtask_encryption_secret}
      '';
    };
  };
}
