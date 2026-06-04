# nix-test — Home Manager sandboxes

Throwaway Debian containers that install Nix from scratch and run a **real
`home-manager switch`**, so you can verify the flake end-to-end without touching
your real machine. Three flavours, by use case:

| File | Source tested | Loop speed | Use it for |
|---|---|---|---|
| `dev.sh` + `Dockerfile.dev` | **local working tree** (live) | **fast** (persistent `/nix`) | iterating on WIP |
| `Dockerfile.local` | local working tree (baked) | slow (full rebuild) | one-shot WIP snapshot |
| `Dockerfile` | **committed branch** (cloned) | slow (full rebuild) | "does a fresh clone work" |

Start your Docker daemon (OrbStack / Docker Desktop / colima) first.

## fast dev loop (recommended) — `dev.sh`

Builds a tiny base image (just Nix), then activates your **local** config at
runtime against a bind-mount, with a persistent `/nix` volume so the toolchain
downloads only once.

```sh
./nix-test/dev.sh                 # activate romance@debian on this arch, drop into zsh
./nix-test/dev.sh romance@wsl     # a different host
```

Edit your config on the host, re-run `./nix-test/dev.sh`, and `switch` is fast
(store cached). Uncommitted **and** untracked files are included (the tree is
synced into a path flake, so Nix sees everything — no `git add` needed).

- First run downloads the whole toolchain into the `hm-nix` volume (slow, once).
- Reset the cached store with `docker volume rm hm-nix`.

## one-shot, baked images

```sh
# local working tree, baked into an image:
docker build -f nix-test/Dockerfile.local -t hm-test-local .   # context = repo root
docker run --rm -it hm-test-local

# the committed/pushed branch (what another machine would clone):
docker build -t hm-test ./nix-test
docker run --rm -it hm-test
docker build --build-arg REF=my-branch --build-arg HM_HOST=romance@wsl -t hm-test ./nix-test
```

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
