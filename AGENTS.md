# AGENTS.md

Shared instructions for AI coding agents (Copilot CLI, Codex, Cursor, etc.).
Claude Code reads these via `CLAUDE.md`, which imports this file.

## Compatibility Rules

All the decisions and implementations of this repo should consider the following platforms in mind:

- WSL (on x64 Windows Architecture)
- MacOS

Everything must be managed through nix (not homebrew, not apt) unless explicitly stated

If there is a package that is not available on both, configuration should handle the platform-specific case

## What this repo is

Personal dotfiles for tmux, zsh, and shell utilities, managed with **Nix /
Home Manager**. A flake (`flake.nix` + `home/*.nix`) reproduces the environment
on macOS, WSL, and Debian. The `home/` modules are the source of truth: they
declare the shell, tools, and configs as native `programs.*` modules. The
`.local/bin/` scripts are installed verbatim into `~/.local/bin`.

See `README.md` for full setup and migration details.

## Source-of-truth rules

- The `home/*.nix` modules are the source of truth. Edit those (or the config
  files they reference under `home/`), not the symlinks in `$HOME`.
- Shell config lives in `home/shell.nix` (zsh: aliases, env, keybindings,
  functions); tmux in `home/tmux.nix`; per-tool configs in `home/programs.nix`.
- On a Home Manager machine the linked files in `$HOME` are **read-only symlinks
  into `/nix/store`** — never edit them in place. Edit the source here, then
  re-activate.

## Architecture (hosts, profiles, secrets)

- **Profiles** compose hosts. `home/profiles/base.nix` is the universal role
  (shell, packages, programs, tmux, scripts); `home/profiles/personal.nix` =
  base + personal-only modules (taskwarrior/secrets, herdr, alien).
  `mkHome` in `flake.nix` picks a `profile` and optional `extraModules` per
  host — don't wire host-specific `imports` into the leaf modules.
- **Host roles.** `mkHome` also takes boolean role flags (`isWSL`, `isAlien`,
  `isServer`) threaded to modules via `extraSpecialArgs`. `isServer` marks a box
  that runs the distro's system dockerd and should get the heavy docker/server
  tooling (docker CLI, lazydocker, portainer); client-only boxes leave it false
  and stay lean. It's **hardcoded** for fixed-identity hosts (`alien` = server,
  `pi` = client) and **read per-machine from `local.nix`** (`isServer = local.isServer or false`)
  for the shared configs (`wsl`/`debian`/`work`) — because one `wsl` config
  serves several physical boxes with different roles. macOS is unaffected (it
  gets docker via colima in the `isDarwin` block regardless).
- **Secrets** use **sops-nix**. Encrypted values live in `secrets.yaml`
  (committed), decrypted at activation via each host's SSH ed25519 key (see
  `.sops.yaml` recipients and `home/secrets.nix`). Edit with `sops secrets.yaml`;
  add a host with `ssh-to-age < ~/.ssh/id_ed25519.pub` → `.sops.yaml` →
  `sops updatekeys secrets.yaml`. Never put a real secret in `local.nix`.
- **Work config is private.** Internal hostnames/usernames/Dev Tunnel ids live
  in the separate private `work-dotfiles` flake input, layered onto the `osx`
  and `work` hosts only. Keep work metadata out of this public repo.
- **Unreachable private input.** Nix fetches *all* flake inputs eagerly, so a
  node that can't reach the private `work-dotfiles` repo (e.g. the JD work box /
  `remote-left`, whose git identity has no access) can't build *any* output —
  even `.#wsl`, which never imports it. Such nodes run `.#wsl` against the same
  committed flake by overriding that input with the empty stub at `nix/wd-stub`:
  `--override-input work-dotfiles path:./nix/wd-stub`. The `hm-switch` wrapper
  (below) applies this automatically when the input is unreachable, so every
  node builds identical HEAD — no per-host `flake.nix` fork.

## Making changes

- Every time we edit `home/*.nix` module or a referenced config file, then run:
  ```sh
  hm-switch <host>            # host: osx | wsl | debian | pi | work
  # equivalently: home-manager switch --flake .#<host>
  ```
  Prefer `hm-switch` (`.local/bin/hm-switch`): it's a thin wrapper that auto-
  overrides the private `work-dotfiles` input with the `nix/wd-stub` empty stub
  on boxes that can't fetch it (see the private-input note above), and is a
  plain passthrough everywhere else.
- Validate Nix changes without applying: `nix flake check`.
- **Commit `flake.lock`** when it changes — it pins exact package versions.
- For tmux-related changes reload tmux's config

## Deploying to remote Tailscale nodes

Use `nix-deploy` (`.local/bin/nix-deploy`, installed into `~/.local/bin`):

```sh
nix-deploy                   # deploy to all configured nodes (pi, alien)
nix-deploy alien             # deploy to a single node
nix-deploy --dry-run alien   # build without activating — catches eval/build errors first
nix-deploy --force alien     # hard-reset remote repo to origin/master (drops local commits)
```

The script SSHes into each node, pulls latest from origin, then runs
`home-manager switch`. If the remote has local commits not on origin it aborts
and lists them so they can be integrated first. Add new nodes by extending the
`FLAKE_TARGET` map at the top of the script.

## Conventions

- tmux prefix is `C-a`; tmux and shell both use **vi** bindings.
- Shell utilities live in `.local/bin/` (e.g. `tmux-sessionizer`,
  `tmux-launcher`).
- **Containers:** on Linux the daemon is the distro's native **system dockerd**
  (managed outside nix via systemd/root — install with the OS package, e.g.
  `apt install docker.io`, then `systemctl enable --now docker` and
  `usermod -aG docker <user>`), **not colima**. macOS uses colima (QEMU/Lima VM)
  since it can't run a native Linux daemon. Nix ships the `docker` CLI (plus
  lazydocker + the portainer launcher) only on hosts flagged `isServer` (see the
  Host roles note above) — `alien`, and any `wsl`/`debian`/`work` box that sets
  `isServer = true;` in its `local.nix`. The CLI must use the `default` docker context
  (`unix:///var/run/docker.sock`) — remove any leftover `colima` context with
  `docker context use default && docker context rm colima`.

## Gotchas

- Home Manager never overwrites files it didn't create; pre-existing files cause
  an "in the way" abort. Use `switch -b backup` to move them aside.
- Keep `local.nix` machine-specific; `local.nix.example` is the template.
- **SF Mono in Ghostty (macOS):** macOS blocks third-party apps from loading
  user-installed fonts named "SF Mono" (CoreText silently rejects them). The
  fix is to copy the fonts out of Terminal.app's bundle, which ships the
  original Apple-signed OTF/TTFs:
  ```sh
  cp /System/Applications/Utilities/Terminal.app/Contents/Resources/Fonts/SFMono*Terminal.ttf ~/Library/Fonts/
  ```
  After that, `font-family = SF Mono Terminal` works in `home/ghostty/config`
  (this is the `SFMonoTerminal-*` family — the variant Terminal.app itself
  uses). This is a one-time manual step — Nix cannot manage it because the
  source files live inside a system app bundle.
