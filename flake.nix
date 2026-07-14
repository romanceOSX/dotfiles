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
    # nix-darwin — macOS system layer. Used only for the things Home Manager
    # can't express on macOS (root LaunchDaemons). See darwinConfigurations
    # below and ./darwin. Follows the same nixpkgs so the system-managed
    # tailscaled and the Home Manager tailscale CLI stay in lockstep.
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    herdr.url = "github:ogulcancelik/herdr";
    # sops-nix — secrets management. Secrets live encrypted in ./secrets.yaml
    # (committed) and are decrypted at activation with the host's SSH ed25519
    # key (see home/secrets.nix and .sops.yaml). Follows the same nixpkgs so the
    # sops/age tooling matches the rest of the system.
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Private work configuration — internal hostnames, usernames, and Dev Tunnel
    # ids that must not leak into this public repo. Only the osx + work hosts
    # reference its module (see extraModules below), so the personal hosts (wsl,
    # debian, alien, pi) still evaluate without access to this private repo.
    # It exports a pure Home Manager module and has no nixpkgs input of its own.
    work-dotfiles.url = "git+ssh://git@github.com/romanceOSX/work-dotfiles.git";
  };

  outputs =
    { nixpkgs, nixpkgs-neovim, home-manager, nix-darwin, herdr, sops-nix
    , work-dotfiles, ... }:
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

      # Host roles — three nested deployment flavors, server ⊇ client ⊇ minimal.
      #   minimal — IoT/appliance tier (e.g. the Pi): usable shell + core CLI +
      #             editor + monitoring, no heavy dev/build tooling. Uses the
      #             lean base.nix profile.
      #   client  — full workstation: minimal + language toolchains, LSPs,
      #             formatters, editor tooling, personal apps. Uses personal.nix.
      #   server  — a client that also runs services: client + the distro-dockerd
      #             tooling (docker CLI, lazydocker, portainer; Linux only).
      # Higher rank = more surface. `roleAtLeast` lets modules gate on a tier.
      roleRank = { minimal = 0; client = 1; server = 2; };
      validRole = r:
        if builtins.hasAttr r roleRank then r
        else throw ''dots: invalid role "${toString r}" — expected "minimal", "client", or "server".'';
      # Curried: (mkRoleAtLeast "client") "minimal" == true. Passed per host as
      # `roleAtLeast` so modules can do `roleAtLeast "client"` → bool.
      mkRoleAtLeast = current: threshold: roleRank.${current} >= roleRank.${threshold};

      # Systems this repo is ever activated on. Used only for the dev shell
      # below — the per-host homeConfigurations pin their own system.
      forAllSystems = nixpkgs.lib.genAttrs [
        "aarch64-darwin"
        "x86_64-darwin"
        "x86_64-linux"
        "aarch64-linux"
      ];

      # Build a Home Manager configuration for one host.
      #   system        — nix system double (e.g. "x86_64-linux", "aarch64-darwin")
      #   username       — your login name on that machine
      #   homeDirectory  — absolute path to $HOME on that machine
      #   isWSL          — true under WSL (Syncthing then runs on the Windows host,
      #                    not via nix). Defaults to false (bare Linux / macOS).
      #   role           — deployment flavor: "minimal" | "client" | "server"
      #                    (default "client"). Picks the profile (minimal→base.nix,
      #                    client/server→personal.nix), the package tier, and the
      #                    docker/server tooling. See the role note above.
      #   profile        — escape hatch to force a specific profile module path,
      #                    overriding the role→profile mapping. Defaults to null
      #                    (derive from role).
      #   extraModules   — additional Home Manager modules layered on top of the
      #                    profile (e.g. the private work module for the work host).
      mkHome =
        { system, username, homeDirectory, isWSL ? false, isAlien ? false
        , role ? "client"
        , profile ? null
        , extraModules ? [ ] }:
        let
          checkedRole = validRole role;             # throws on a bad enum (lazy, per-host)
          roleAtLeast = mkRoleAtLeast checkedRole;   # helper: roleAtLeast "client" → bool
          isServer = checkedRole == "server";
          includeHerdr = roleAtLeast "client";       # minimal ⇒ no herdr (also pi's aarch64 win)
          selectedProfile =
            if profile != null then profile
            else if roleAtLeast "client" then ./home/profiles/personal.nix
            else ./home/profiles/base.nix;
        in
        home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
          extraSpecialArgs = {
            pkgs-neovim = import nixpkgs-neovim {
              inherit system;
              config.allowUnfree = true;
            };
            # herdr — AI agent multiplexer (like tmux, but for coding agents).
            # Only client+ hosts get it (minimal drops it, which also avoids the
            # from-source Rust compile on aarch64 hosts like the Pi).
            herdr = if includeHerdr then herdr.packages.${system}.default or null else null;
            inherit isWSL;
            # Gates the Alienware-only utilities (rom-alien-rgb-*). True only for
            # the "alien" host below; every other host gets `false` via the
            # default, so the OpenRGB wrappers never land on machines without
            # that hardware. See home/alien.nix.
            inherit isAlien;
            # Host role + tier helper (see the role note above). `role` and
            # `roleAtLeast` gate package tiers and modules; `isServer` is the
            # derived `role == "server"` convenience for the docker/server gates
            # in home/packages.nix + home/portainer.nix.
            inherit role roleAtLeast isServer;
            # WingTask cloud sync (Taskwarrior) — only the non-secret server URL
            # is read off `local` here; it doubles as the per-host "sync on?"
            # gate. The sensitive client_id + encryption_secret now live
            # encrypted in ./secrets.yaml and are decrypted at activation by
            # sops-nix (see home/secrets.nix), so ANY host opts in just by
            # setting wingtaskServerUrl in its local.nix. null → left out of the
            # mesh. See home/taskwarrior.nix.
            wingtaskServerUrl = local.wingtaskServerUrl or null;
          };
          modules = [
            sops-nix.homeManagerModules.sops
            selectedProfile
            {
              home.username = username;
              home.homeDirectory = homeDirectory;
            }
          ] ++ extraModules;
        };
    in
    {
      # Activate with:  home-manager switch --flake .#<name>
      homeConfigurations = {
        # current macOS machine (Apple Silicon). Defaults to the client role;
        # drop `role = "server";` in local.nix to flip it (Mac servers just use
        # colima docker — the Linux server package/portainer block stays off).
        "osx" = mkHome {
          system = "aarch64-darwin";
          username = "romance";
          homeDirectory = "/Users/romance";
          role = local.role or "client";
          # The Mac is the Dev Tunnel client for the work boxes, so it pulls in
          # the private work SSH hosts (axxis-*). Requires access to the private
          # work-dotfiles repo to build.
          extraModules = [ work-dotfiles.homeModules.default ];
        };

        # WSL (Ubuntu/Debian under Windows) — uses local.nix identity.
        # This one config is shared by multiple physical WSL boxes with different
        # roles (some servers running dockerd, some pure clients, some minimal),
        # so `role` is read per-machine from local.nix (`role = "server";` etc).
        "wsl" = mkHome {
          system = "x86_64-linux";
          isWSL = true; # Syncthing runs on the Windows host, not via nix here
          role = local.role or "client";
          inherit (local) username homeDirectory;
        };

        # bare-metal / VM Debian — uses local.nix identity
        "debian" = mkHome {
          system = "x86_64-linux";
          role = local.role or "client";
          inherit (local) username homeDirectory;
        };

        # work machine (bare Linux, inside a VPN) — uses local.nix identity.
        # Set wingtaskServerUrl in its local.nix to join the task-sync mesh
        # (the encrypted creds come from sops — see home/secrets.nix).
        "work" = mkHome {
          system = "x86_64-linux";
          role = local.role or "client";
          inherit (local) username homeDirectory;
          extraModules = [ work-dotfiles.homeModules.default ];
        };

        # Build server (bare-metal Ubuntu, x86_64, Intel i7-8750H 6c/12t, 14 GB).
        # Identity is hardcoded — no local.nix needed on the headless server.
        "alien" = mkHome {
          system = "x86_64-linux";
          username = "romance";
          homeDirectory = "/home/romance";
          isAlien = true; # unlocks rom-alien-rgb-* (OpenRGB wrappers, see home/alien.nix)
          role = "server"; # build server — full dev tier + distro dockerd tooling
        };

        # Raspberry Pi (64-bit Raspberry Pi OS / Debian Bookworm, aarch64).
        # Identity is hardcoded so the headless Pi needs no local.nix.
        # Minimal role — core shell/CLI/editor only, no dev tier. This also drops
        # herdr, whose from-source Rust build has no aarch64 binary cache and
        # takes hours on Pi hardware.
        "pi" = mkHome {
          system = "aarch64-linux";
          username = "romance";
          homeDirectory = "/home/romance";
          role = "minimal";
        };
      };

      # Dev shell for this repo. Exists mainly so the root .envrc's
      # `use flake . --impure` resolves (nix-direnv needs a devShells.default);
      # entering the repo dir then also drops you into a shell with the tools
      # used to maintain it. References only nixpkgs, so it evaluates on the
      # personal hosts without access to the private work-dotfiles input.
      devShells = forAllSystems (system:
        let pkgs = nixpkgs.legacyPackages.${system};
        in {
          default = pkgs.mkShellNoCC {
            packages = [ pkgs.sops pkgs.age pkgs.ssh-to-age ];
            shellHook = ''
              echo "dots devshell — .env loaded via direnv; sops/age available"
            '';
          };
        });

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
