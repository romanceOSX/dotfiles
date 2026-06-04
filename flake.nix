{
  description = "romance's reproducible environment (Home Manager / native modules)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, home-manager, ... }:
    let
      # Machine-local identity — each host defines local.nix once (gitignored).
      # Falls back to sensible defaults if missing.
      local =
        if builtins.pathExists ./local.nix
        then import ./local.nix
        else { username = "romance"; homeDirectory = "/home/romance"; };

      # Build a Home Manager configuration for one host.
      #   system        — nix system double (e.g. "x86_64-linux", "aarch64-darwin")
      #   username       — your login name on that machine
      #   homeDirectory  — absolute path to $HOME on that machine
      mkHome =
        { system, username, homeDirectory }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
          modules = [
            ./home
            {
              home.username = username;
              home.homeDirectory = homeDirectory;
            }
          ];
        };
    in
    {
      # Activate with:  home-manager switch --flake .#<name>
      homeConfigurations = {
        # current macOS machine (Apple Silicon)
        "romance@mac" = mkHome {
          system = "aarch64-darwin";
          username = "romance";
          homeDirectory = "/Users/romance";
        };

        # WSL (Ubuntu/Debian under Windows) — uses local.nix identity
        "romance@wsl" = mkHome {
          system = "x86_64-linux";
          inherit (local) username homeDirectory;
        };

        # bare-metal / VM Debian — uses local.nix identity
        "romance@debian" = mkHome {
          system = "x86_64-linux";
          inherit (local) username homeDirectory;
        };
      };
    };
}
