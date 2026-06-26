{
  description = "romance's home-manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Pinned to the nixpkgs commit that first shipped neovim 0.12.0 (before
    # the 0.12.2 treesitter core regression — vim.treesitter.get_range crashes
    # on markdown injection queries with "attempt to call method 'range' (a
    # nil value)"). 0.11.x lacks features aerial.nvim needs, so 0.12.0 is the
    # sweet spot. The editor is pinned independently of the rest of the system
    # packages — see home/packages.nix.
    nixpkgs-neovim.url = "github:NixOS/nixpkgs/ccb635f945aa6d34300627e70633878645db2db3";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Agent of Empires — session manager for AI coding agents (Rust).
    # Consumed as a flake package; `aoe` is wired into home.packages.
    agent-of-empires = {
      url = "github:agent-of-empires/agent-of-empires";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # nix-darwin — macOS system layer. Used only for the things Home Manager
    # can't express on macOS (root LaunchDaemons). See darwinConfigurations
    # below and ./darwin. Follows the same nixpkgs so the system-managed
    # tailscaled and the Home Manager tailscale CLI stay in lockstep.
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, nixpkgs-neovim, home-manager, agent-of-empires, nix-darwin, ... }:
    let
      # Machine-local identity — each host defines local.nix once (gitignored).
      # Sensible personal defaults are merged with (and overridden by) local.nix,
      # so a host that omits a field still gets the default. Git identity is NOT
      # set here — it lives in ~/.config/git/config.local (see home/programs.nix).
      localDefaults = {
        username = "romance";
        homeDirectory = "/home/romance";
      };
      local =
        localDefaults
        // (if builtins.pathExists ./local.nix then import ./local.nix else { });

      # Build a Home Manager configuration for one host.
      #   system        — nix system double (e.g. "x86_64-linux", "aarch64-darwin")
      #   username       — your login name on that machine
      #   homeDirectory  — absolute path to $HOME on that machine
      #   isWSL          — true under WSL (Syncthing then runs on the Windows host,
      #                    not via nix). Defaults to false (bare Linux / macOS).
      mkHome =
        { system, username, homeDirectory, isWSL ? false, isAlien ? false, includeAoe ? true }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
            # libolm is EOL/deprecated upstream (superseded by vodozemac) and so
            # marked insecure in nixpkgs, but matrix-nio — pulled in by the
            # weechat-matrix client in home/messaging.nix — still depends on it.
            # The messaging stack is local-only and unfederated, so the exposure
            # is negligible; permit it consciously.
            config.permittedInsecurePackages = [ "olm-3.2.16" ];
          };
          extraSpecialArgs = {
            pkgs-neovim = import nixpkgs-neovim {
              inherit system;
              config.allowUnfree = true;
            };
            # Agent of Empires `aoe` binary, built from its own flake.
            # Set includeAoe = false for hosts where compiling Rust from source
            # is impractical (e.g. Raspberry Pi with no binary cache).
            aoe = if includeAoe then agent-of-empires.packages.${system}.default else null;
            inherit isWSL;
            # Gates the Alienware-only utilities (rom-alien-rgb-*). True only for
            # the "alien" host below; every other host gets `false` via the
            # default, so the OpenRGB wrappers never land on machines without
            # that hardware. See home/alien.nix.
            inherit isAlien;
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
        "osx" = mkHome {
          system = "aarch64-darwin";
          username = "romance";
          homeDirectory = "/Users/romance";
        };

        # WSL (Ubuntu/Debian under Windows) — uses local.nix identity
        "wsl" = mkHome {
          system = "x86_64-linux";
          isWSL = true; # Syncthing runs on the Windows host, not via nix here
          inherit (local) username homeDirectory;
        };

        # bare-metal / VM Debian — uses local.nix identity
        "debian" = mkHome {
          system = "x86_64-linux";
          inherit (local) username homeDirectory;
        };

        # work machine (bare Linux, inside a VPN) — uses local.nix identity.
        # Not WSL, so Syncthing runs via nix; pair it into the task-sync mesh
        # by adding its `syncthing --device-id` to syncthingDevices.
        "work" = mkHome {
          system = "x86_64-linux";
          inherit (local) username homeDirectory;
        };

        # Build server (bare-metal Ubuntu, x86_64, Intel i7-8750H 6c/12t, 14 GB).
        # Identity is hardcoded — no local.nix needed on the headless server.
        "alien" = mkHome {
          system = "x86_64-linux";
          username = "romance";
          homeDirectory = "/home/romance";
          isAlien = true; # unlocks rom-alien-rgb-* (OpenRGB wrappers, see home/alien.nix)
        };

        # Raspberry Pi (64-bit Raspberry Pi OS / Debian Bookworm, aarch64).
        # Identity is hardcoded so the headless Pi needs no local.nix.
        # aoe is excluded — no binary cache for aarch64-linux means compiling
        # ~761 Rust crates from source, which takes hours on Pi hardware.
        "pi" = mkHome {
          system = "aarch64-linux";
          username = "romance";
          homeDirectory = "/home/romance";
          includeAoe = false;
        };
      };

      # macOS system layer (Apple Silicon). Standalone Home Manager still owns
      # the user environment via homeConfigurations.osx above; nix-darwin manages
      # only the system-level pieces Home Manager can't (the root tailscaled
      # LaunchDaemon). Activate with:
      #   sudo darwin-rebuild switch --flake .#osx
      darwinConfigurations.osx = nix-darwin.lib.darwinSystem {
        modules = [ ./darwin ];
      };
    };
}
