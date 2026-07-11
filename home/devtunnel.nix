{ pkgs, lib, ... }:

# Microsoft Dev Tunnels CLI (`devtunnel`) — expose a local port over a public
# HTTPS URL. Microsoft ships it only as a closed-source prebuilt binary (no
# source, no nixpkgs package), so this module wraps the official per-platform
# download in a derivation and drops it into home.packages.
#
# The download URLs are unversioned "latest" blobs; when Microsoft ships a new
# build the hashes below will stop matching and the fetch will fail. To bump:
#   nix store prefetch-file --json \
#     https://tunnelsassetsprod.blob.core.windows.net/cli/<plat>-devtunnel
# and paste the reported SRI hash for each platform, then update `version`.

let
  version = "1.0.1942";
  baseUrl = "https://tunnelsassetsprod.blob.core.windows.net/cli";

  # nix system double -> { plat = blob token; hash = SRI of that blob }
  sources = {
    "x86_64-linux" = {
      plat = "linux-x64";
      hash = "sha256-Y4DT5UyB5+JUGQC+w9TyeF2/gfF82B7/vVTZjxGodLk=";
    };
    "aarch64-linux" = {
      plat = "linux-arm64";
      hash = "sha256-4j8j5OaMRu4IoenbXWLlwAeFxmy3AjZZe+4OCmQSBRI=";
    };
    "x86_64-darwin" = {
      plat = "osx-x64";
      hash = "sha256-KDqx8g8+br9sNDTTsU4bkJ+bBIIgadme4Z0zIB/9NxA=";
    };
    "aarch64-darwin" = {
      plat = "osx-arm64";
      hash = "sha256-70GX2KHWVk++yHyHUvBKdXPROBDVJ9VHCE4jK3Hue1o=";
    };
  };

  system = pkgs.stdenv.hostPlatform.system;
  source = sources.${system} or (throw "devtunnel: unsupported system ${system}");

  devtunnel = pkgs.stdenv.mkDerivation {
    pname = "devtunnel";
    inherit version;

    src = pkgs.fetchurl {
      url = "${baseUrl}/${source.plat}-devtunnel";
      inherit (source) hash;
    };

    dontUnpack = true;

    # NOTE: These are .NET self-contained single-file apps: a bundle is appended
    # after the ELF and its offsets are stored self-referentially. Running
    # autoPatchelf/patchelf rewrites the ELF and shifts those offsets, corrupting
    # the bundle ("Arithmetic overflow while reading bundle"). So we deliberately
    # do NOT patch. Every host here is a regular distro (WSL/Debian/macOS), never
    # NixOS, so the system dynamic loader is present and runs the binary as-is.
    #
    # The one portability gap: .NET aborts at startup if the host has no libicu
    # ("Couldn't find a valid ICU package installed on the system"), and some WSL
    # images ship without it. We can't just prepend nix libs to LD_LIBRARY_PATH
    # unconditionally: nix's ICU/libstdc++ are built against a newer glibc than
    # some hosts have (e.g. a WSL box on glibc 2.35), so injecting them there
    # breaks a binary that was otherwise fine. Instead, on Linux we wrap with a
    # tiny launcher that adds the nix ICU *only when the host provides none* — so
    # hosts with system ICU are untouched and ICU-less hosts get a working fallback.
    # macOS ships ICU and the Mach-O binary is self-contained, so no wrap there.
    dontPatchELF = true;
    dontStrip = true;

    nativeBuildInputs = lib.optionals pkgs.stdenv.isLinux [ pkgs.makeWrapper ];

    # Keep the real binary under a plain name (no leading dot). devtunnel derives
    # its CLI root-command name from the executable filename, and makeWrapper's
    # usual in-place ".<name>-wrapped" rename yields an empty alias that crashes
    # it ("An alias cannot be null, empty..."). So the untouched binary lives in
    # libexec/ and the wrapper/symlink in bin/ points at it.
    installPhase = ''
      runHook preInstall
      install -Dm755 "$src" "$out/libexec/devtunnel"
      ${lib.optionalString pkgs.stdenv.isDarwin ''
        mkdir -p "$out/bin"
        ln -s "$out/libexec/devtunnel" "$out/bin/devtunnel"
      ''}
      runHook postInstall
    '';

    postFixup = lib.optionalString pkgs.stdenv.isLinux ''
      makeWrapper "$out/libexec/devtunnel" "$out/bin/devtunnel" \
        --run 'if ! ls /usr/lib*/libicuuc.so* /lib*/libicuuc.so* /usr/lib/*/libicuuc.so* >/dev/null 2>&1; then export LD_LIBRARY_PATH="${pkgs.icu}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"; fi'
    '';

    meta = with lib; {
      description = "Microsoft Dev Tunnels CLI — expose local ports over public HTTPS";
      homepage = "https://learn.microsoft.com/azure/developer/dev-tunnels/";
      license = licenses.unfree; # proprietary Microsoft binary
      sourceProvenance = [ sourceTypes.binaryNativeCode ];
      platforms = builtins.attrNames sources;
      mainProgram = "devtunnel";
    };
  };
in
{
  home.packages = [ devtunnel ];
}
