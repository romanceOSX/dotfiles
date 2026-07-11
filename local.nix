# Machine-local overrides for this host (osx). Deliberately NOT gitignored
# (so the flake can read it) but meant to stay uncommitted.
#
# The WingTask client_id + encryption_secret used to live here; they now live
# encrypted in ./secrets.yaml (sops-nix, see home/secrets.nix). Only the
# non-secret server URL remains — it gates whether this host joins the mesh.
{
  wingtaskServerUrl = "https://sync.wingtask.com";
}
