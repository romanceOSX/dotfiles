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
- **Host roles.** `mkHome` takes a `role` — `"minimal" | "client" | "server"`
  (default `client`), nested so **server ⊇ client ⊇ minimal** — plus hardware
  flags (`isWSL`, `isAlien`), all threaded to modules via `extraSpecialArgs`
  along with a `roleAtLeast` helper. `minimal` is the IoT/appliance tier (core
  shell/CLI/editor/monitoring only, uses `base.nix`); `client` adds the dev
  surface — toolchains, LSPs, formatters, herdr, personal apps (uses
  `personal.nix`); `server` adds the distro-dockerd tooling (docker CLI,
  lazydocker, portainer; Linux only). `mkHome` derives the profile
  (minimal→`base.nix`, client/server→`personal.nix`), `includeHerdr`
  (`roleAtLeast "client"`), and `isServer` (`role == "server"`) from it. Package
  tiers gate with `lib.optionals (roleAtLeast "client")` / `(role == "server")`;
  modules self-gate with `lib.mkIf`. Selection: **hardcoded** for fixed-identity
  hosts (`pi = minimal`, `alien = server`) and **read per-machine from
  `local.nix`** (`role = local.role or "client"`) for the shared configs
  (`wsl`/`debian`/`work`) and `osx` — so one `wsl` config serves boxes of
  different roles, and a client flips to server via one line in `local.nix` (or
  `hm-role server`). macOS never gets the Linux server block — a Mac `server`
  just uses its colima docker.
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
  lazydocker + the portainer launcher) only on Linux hosts with `role ==
  "server"` (see the Host roles note above) — `alien`, and any `wsl`/`debian`/`work`
  box that sets `role = "server";` in its `local.nix`. The CLI must use the
  `default` docker context (`unix:///var/run/docker.sock`) — remove any leftover
  `colima` context with `docker context use default && docker context rm colima`.
  (Note `pi` is now `role = "minimal"` — no dev tier at all, not just no docker.)

## Services — Tailscale subdomain routing (`server` hosts)

Server hosts expose docker services on the tailnet under their own MagicDNS
names via **`tsvc`** (`.local/bin/tsvc`, installed by `home/tsvc.nix`, gated
`role == "server" && isLinux`):

```sh
tsvc up portainer            # → https://portainer.<tailnet>.ts.net
tsvc list | status | logs | down
tsvc new <svc> --image IMG --port N [--data VOL[:PATH]] [--mount H:C] [--ephemeral]
```

- **Model: one tailnet device per service (sidecar).** Each service is a 2-
  container compose stack on the host's dockerd — a `tailscale/tailscale`
  userspace sidecar (`hostname: <svc>`, `tag:svc`) running `tailscale serve` to
  front the app on HTTPS `443`, plus the app container sharing the sidecar's
  netns (`network_mode: service:tailscale`). Tailscale issues a valid
  `<svc>.<tailnet>.ts.net` cert — **no wildcard/external domain** (Tailscale only
  certs a node's own name, which is exactly why it's a device *per* service, not
  path-routing on one node). `serve.json` uses the image's `${TS_CERT_DOMAIN}`
  token so the FQDN isn't hardcoded.
- **Service defs** live in `home/tsvc/services/<svc>.env` (nix-installed to
  `~/.config/tsvc/services/`): `SVC_IMAGE` + `SVC_PORT` required; optional
  `SVC_DATA_VOLUME`/`SVC_DATA_PATH`, `SVC_MOUNTS` (e.g. the docker socket for
  portainer), `SVC_CMD` (args appended to the entrypoint), `SVC_PULL`,
  `EPHEMERAL`. Checked-in: `portainer` (docker UI), `paisa` (finance UI — binds
  `$HOME/finance` into paisa's `~/Documents/paisa`). Add a permanent service =
  new `.env` in the repo + `hm-switch`; `tsvc new` scaffolds ad-hoc ones.
- **Not everything fits tsvc.** The model is one node → one port → one
  Tailscale cert. A multi-origin app that terminates its own TLS and routes
  sub-domains (e.g. the `meddy` dev stack: its own nginx serving
  `www./app./api.${ROOT_DOMAIN}` under a mkcert wildcard) does **not** fit —
  Tailscale won't cert per-node subdomains. Expose those via their own mechanism
  (meddy: run its compose with `ROOT_DOMAIN` set to alien's tailnet name).
  Note also that alien's ufw is `INPUT policy DROP`, so a container cannot reach
  a build on the host via `host-gateway` — a sidecar can only front another
  container (shared netns), not an arbitrary host process.
- **Auth: a Tailscale OAuth client secret** (scope `auth_keys`, tag `tag:svc`),
  stored in sops as `tailscale_svc_oauth` (see `home/secrets.nix`, gated to
  servers). tsvc reads the sops-rendered path from `~/.config/tsvc/config.env`
  and mints **ephemeral, non-expiring** keys — new services need no key rotation.
- **Tailnet prerequisites** (admin console, one-time): enable **HTTPS
  Certificates** (DNS page), and add `tag:svc` + `tagOwners` and a grant letting
  members reach `tag:svc` in the ACL policy, then create the OAuth client.
- The standalone `portainer` launcher (`home/portainer.nix`) still exists for a
  localhost-only container; don't run it and `tsvc up portainer` at once — they
  share the `portainer_data` volume.

## System-wide reverse proxy (tier1) — `server` hosts

**`system-proxy`** (`.local/bin/system-proxy`, installed by
`home/system-proxy.nix`, same gate as tsvc) is the *only* thing bound to a
server host's real `0.0.0.0:80/443`. It's a single dockerized nginx that
TLS-terminates with one mkcert wildcard cert for a fixed `ROOT_DOMAIN`
(currently `meddy.test`, hardcoded in the .nix file — this host only runs one
multi-origin project today) and fans out by Host header to each project's own
loopback-published port, e.g. `portainer.meddy.test` → tsvc's
loopback-published `:9000`. It never joins another project's docker network —
runs with `--network host` so its own `127.0.0.1` *is* the real host
loopback (backends publish to `127.0.0.1` only, which refuses connections via
the docker0 bridge gateway/`host.docker.internal` — genuine loopback is the
only path in). Projects stay fully independent compose stacks; system-proxy
only knows their loopback port.

```sh
system-proxy certs             # one-time: mkcert wildcard cert for ROOT_DOMAIN
system-proxy start             # → https://<ROOT_DOMAIN> (and *.<ROOT_DOMAIN>)
system-proxy reload            # picked up a config change (hm-switch first)
system-proxy status | logs | stop | update
```

- **Getting a service in front of it** needs two moves: (1) publish the
  service's port to `127.0.0.1` (tsvc: set `SVC_PUBLISH_HOST=127.0.0.1` in its
  `.env` — note it has to go on the `tailscale` sidecar service, not `app`,
  since Docker refuses to publish a port on a container using
  `network_mode: service:X`; non-tsvc projects do this in their own compose
  file), and (2) add a `server{}` block in `home/system-proxy.nix`'s
  `defaultConf` proxying to `127.0.0.1:<port>` — **not**
  `host.docker.internal`, see below — then `hm-switch` + `system-proxy reload`.
- **`ufw`'s default is `INPUT policy DROP`, and it matters differently for
  different hops.** A *bridge-networked* container reaching a host-bound port
  via `host.docker.internal`/`host-gateway` (e.g. meddy's own nginx → the API
  on `:3000`) needs an explicit `ufw allow ... to any port <N>` carve-out —
  that's the pre-existing `3000/tcp` rule. system-proxy sidesteps this
  entirely by running with `--network host`: its own `127.0.0.1` is the real
  host loopback, which already bypasses ufw's INPUT chain unconditionally, no
  rule needed. (This is also *why* it runs that way — ports published to
  `127.0.0.1` refuse connections arriving via the docker0 bridge gateway, so
  `host.docker.internal` wouldn't reach them at all, ufw rule or not.) Separately,
  cross-*project* container-to-container traffic doesn't work here regardless
  of ufw — Docker's own per-network isolation drops it — which is why nothing
  above ever attaches to another project's docker network.
- **meddy specifically** stays a two-tier setup: system-proxy is tier1,
  meddy's *own* nginx (still doing its full `web./app./api.${ROOT_DOMAIN}`
  split, untouched — and now plain HTTP only, it never terminates TLS itself,
  same reasoning as everything above: one edge terminator, everything behind
  it plain, matching how a real SaaS runs) is tier2, rebound from the host's
  real `80` to `127.0.0.1:8080` via meddy's own gitignored
  `docker-compose.override.yml` (see `deploy/tailscale-proxy/README.md` and
  `docs/dev-single-origin.md` in that repo for the tier1/tier2 background).
  That override must use compose's `!override` YAML tag on `ports:`, not a
  plain list — Compose *merges* array fields across files by default, so a
  plain list would leave the base file's `"80:80"` published too and never
  actually free the port for system-proxy.
- **The `docker-compose.override.yml` pattern itself** (meddy, and worth
  reusing for any other project host here): the *committed* compose file
  ships with no restart policy and no host-topology opinions at all — a
  laptop dev running the same repo doesn't want its Postgres/nginx
  auto-launching on every boot, and doesn't have a system-proxy in front to
  rebind ports for. Persistence and port rebinding are host decisions, not
  project ones, so they live in a local, gitignored
  `docker-compose.override.yml` instead — `restart: unless-stopped` on every
  service, plus whatever port surgery this specific host needs. Same
  boot-survival mechanism as everything else on this page: Compose just sets
  the restart policy on the container; actually coming back after a reboot is
  `docker.service` being enabled (`systemctl is-enabled docker`) restarting
  dockerd, which then restarts anything with that policy — no separate
  systemd unit or nix module needed per project.

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
