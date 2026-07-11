# sops-nix secrets — decrypt the WingTask sync credentials at activation.
#
# The encrypted values live in ../secrets.yaml (committed, encrypted to my SSH
# ed25519 key via .sops.yaml). This replaces the old scheme where the
# client_id + encryption_secret were hand-copied into every host's gitignored
# local.nix and had to be kept byte-identical by hand: now each host in the
# mesh decrypts the *same* ciphertext with its own SSH key, so they're
# automatically consistent.
#
# Only the (non-secret) WingTask server URL still comes from local.nix — it
# doubles as the build-time "is sync configured on this host?" gate, since the
# encrypted payload is opaque at eval time. A host with no wingtaskServerUrl
# declares no sops secrets, and `config = mkIf (secrets != {})` upstream makes
# the whole sops module a no-op there.
{ config, lib, wingtaskServerUrl ? null, ... }:
let
  wingtaskConfigured = wingtaskServerUrl != null;
in
lib.mkIf wingtaskConfigured {
  sops = {
    defaultSopsFile = ../secrets.yaml;

    # Derive the age identity from this host's SSH ed25519 private key (the
    # same key already used for git/ssh). No separate age key to distribute.
    age.sshKeyPaths = [ "${config.home.homeDirectory}/.ssh/id_ed25519" ];

    secrets.wingtask_client_id = { };
    secrets.wingtask_encryption_secret = { };

    # Rendered (0400) at activation to
    #   ~/.config/sops-nix/secrets/rendered/taskrc-sync
    # and pulled into taskrc via `include` (see home/taskwarrior.nix), so the
    # decrypted secret never lands in the world-readable generated taskrc.
    templates."taskrc-sync".content = ''
      sync.server.url=${wingtaskServerUrl}
      sync.server.client_id=${config.sops.placeholder.wingtask_client_id}
      sync.encryption_secret=${config.sops.placeholder.wingtask_encryption_secret}
    '';
  };
}
