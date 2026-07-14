{ pkgs, lib, ... }:
let
  version = "1.41.0";

  # Prebuilt release binaries from https://github.com/aaif-goose/goose/releases.
  # We package upstream's official binary rather than building from source: the
  # repo's flake builds goose-cli from source but fails to vendor its git
  # dependency `cudaforge` (no outputHash), so `nix build` on it is broken.
  # nixpkgs' goose-cli also lags well behind (1.28 vs 1.41 here). Each release
  # tarball contains a single dynamically-linked `goose` binary. Bump `version`
  # and refresh the hashes (nix-prefetch-url + nix hash convert) to upgrade.
  targets = {
    "x86_64-linux" = {
      asset = "goose-x86_64-unknown-linux-gnu.tar.gz";
      hash = "sha256-zY54RVc01ozEOrxtrOqOOK4AFg/BJFzpWcNVj9YYmKU=";
    };
    "aarch64-linux" = {
      asset = "goose-aarch64-unknown-linux-gnu.tar.gz";
      hash = "sha256-Cyy2rH3SeViX6q9hkGjaI2hp4RKIWEEhVeA8q7uUNI4=";
    };
    "x86_64-darwin" = {
      asset = "goose-x86_64-apple-darwin.tar.gz";
      hash = "sha256-cDmeDq/gQV0ei5qHb/MZBOW3ktbpqpWNBGJWTKb6ENo=";
    };
    "aarch64-darwin" = {
      asset = "goose-aarch64-apple-darwin.tar.gz";
      hash = "sha256-GRCYR64rx/4sEkpP0G8C8pGEd7uxxNyQumIJYUJ3pnw=";
    };
  };

  system = pkgs.stdenv.hostPlatform.system;
  target = targets.${system} or (throw "goose: unsupported system ${system}");

  goose = pkgs.stdenv.mkDerivation {
    pname = "goose-cli";
    inherit version;

    src = pkgs.fetchurl {
      url = "https://github.com/aaif-goose/goose/releases/download/v${version}/${target.asset}";
      inherit (target) hash;
    };

    sourceRoot = ".";

    # patchelf the ELF interpreter/rpath on Linux; macOS binaries need no fixup.
    nativeBuildInputs = lib.optionals pkgs.stdenv.isLinux [ pkgs.autoPatchelfHook ];
    buildInputs = lib.optionals pkgs.stdenv.isLinux [ pkgs.stdenv.cc.cc.lib ];

    installPhase = ''
      runHook preInstall
      install -Dm755 goose $out/bin/goose
      runHook postInstall
    '';

    meta = with lib; {
      description = "General-purpose AI agent CLI (Agentic AI Foundation)";
      homepage = "https://github.com/aaif-goose/goose";
      license = licenses.asl20;
      mainProgram = "goose";
      platforms = builtins.attrNames targets;
    };
  };
in
{
  home.packages = [ goose ];
}
