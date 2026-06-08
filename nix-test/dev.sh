#!/usr/bin/env sh
# Fast dev loop for the Home Manager config.
#
# Builds the Nix base image once, then activates your LOCAL working tree at
# runtime with a persistent /nix volume — so the toolchain downloads ONCE and
# every later run is fast. Edit your config on the host, re-run this, done.
#
#   ./nix-test/dev.sh                 # debian on this machine's arch, user `romance`
#   ./nix-test/dev.sh wsl             # a different host
#   ./nix-test/dev.sh debian alice    # test under a DIFFERENT username
#
# The second arg overrides the container's login name so you can verify the
# flake works on machines where you're not `romance`. The entrypoint writes a
# matching local.nix from the container's identity, which the flake reads.
#
# First run: downloads the toolchain (slow, one time). Later runs: store cached.
# Reset the cache with:  docker volume rm hm-nix
set -e

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
HM_HOST="${1:-debian}"
USERNAME="${2:-romance}"
# Tag per username so each identity's image layers stay independently cached.
IMAGE="hm-dev-${USERNAME}"

# (Re)build the base image. Cheap after the first time — it's just Nix, no config.
docker build -t "$IMAGE" --build-arg USERNAME="$USERNAME" -f "$HERE/Dockerfile.dev" "$HERE"

exec docker run --rm -it \
  -e HM_HOST="$HM_HOST" \
  -v hm-nix:/nix \
  -v "$REPO":/src:ro \
  "$IMAGE"
