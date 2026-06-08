# nix-test — Home Manager sandbox

A throwaway Debian container that installs Nix from scratch and runs a **real
`home-manager switch`**, so you can verify the flake end-to-end without touching
your real machine.

| File | Source tested | Loop speed | Use it for |
|---|---|---|---|
| `dev.sh` + `Dockerfile.dev` | **local working tree** (live) | **fast** (persistent `/nix`) | iterating on WIP |

Start your Docker daemon (OrbStack / Docker Desktop / colima) first.

## fast dev loop (recommended) — `dev.sh`

Builds a tiny base image (just Nix), then activates your **local** config at
runtime against a bind-mount, with a persistent `/nix` volume so the toolchain
downloads only once.

```sh
./nix-test/dev.sh                 # host `debian` as user romance, drop into zsh
./nix-test/dev.sh wsl             # a different flake host
```

Edit your config on the host, re-run `./nix-test/dev.sh`, and `switch` is fast
(store cached). Uncommitted **and** untracked files are included (the tree is
synced into a path flake, so Nix sees everything — no `git add` needed).

- First run downloads the whole toolchain into the `hm-nix` volume (slow, once).
- Reset the cached store with `docker volume rm hm-nix`.

### testing a different username

Other machines won't have you as `romance`. Pass a username as the 2nd arg to
build the container under that login and verify the flake activates cleanly:

```sh
./nix-test/dev.sh debian alice    # same config, but as user `alice`
```

How it works: the flake reads machine-local identity from a gitignored
`local.nix` (falling back to `romance`). The container's entrypoint generates
that `local.nix` from its own `$USER`/`$HOME`, so `home.username` /
`home.homeDirectory` follow the chosen login automatically. The UID is pinned to
1000 for every username, so the shared `hm-nix` store volume stays reusable.
Each username gets its own image tag (`hm-dev-<username>`) so builds stay cached
independently.

## notes

- **Runs natively** (no QEMU): the linux host's `x86_64-linux` is rewritten to
  the build/run arch (`$(uname -m)-linux`), so on Apple Silicon it's
  `aarch64-linux` from the arm64 cache — no platform-mismatch warning.
- `sandbox = false` / `filter-syscalls = false` (Nix's seccomp can't load in the
  container) and `http2 = false` (avoids `cache.nixos.org` HTTP/2 framing errors)
  live in each image's `/etc/nix/nix.conf`.
- Activation uses `-b backup`, so any base files get renamed to `*.backup`
  instead of aborting — the migration behaviour from the top-level README.
- Nothing here is linked into `$HOME` by stow (see `.stow-local-ignore`).
