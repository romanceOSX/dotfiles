# Shells, channels, and reproducibility

How Nix decides *which* packages you get, why the old way isn't reproducible, and
how flakes fix it.

## `nix-shell` vs `nix shell`

They look like typos of each other but are different generations of tooling.

| Old (channels)        | New (flakes)              | Purpose                              |
|-----------------------|---------------------------|--------------------------------------|
| `nix-shell -p pkg`    | `nix shell nixpkgs#pkg`   | ad-hoc: just put tools on `PATH`     |
| `nix-shell` (shell.nix) | `nix develop`           | enter a project's **dev/build** env  |

- **`nix-shell`** (hyphen) — classic command. Resolves packages via the ambient
  `NIX_PATH`/channels (mutable global state), so *not* reproducible. Also powers
  `#!/usr/bin/env nix-shell` shebang scripts.
- **`nix shell`** (space) — flakes-era subcommand. Pulls packages from a *pinned
  flake reference*, so reproducible. Only puts binaries on `PATH`.

Trap: the flakes counterpart to a classic `nix-shell` *dev environment* is
**`nix develop`**, not `nix shell`. `nix shell` is only the ad-hoc "give me these
binaries" case; `nix develop` reproduces a derivation's full build environment
(compilers, env vars, build inputs) from a `devShell` output in `flake.nix`.

## What a "channel" actually is

A channel is Nix's old mechanism for answering: *"when my config says
`pkgs.ripgrep`, which version of nixpkgs do I get it from?"*

- `nixpkgs` is a giant git repo describing all packages.
- A channel is a **named subscription to a snapshot of that repo**:
  `nix-channel --add <url> nixpkgs` then `nix-channel --update` downloads
  *whatever the latest snapshot is right now* and stores it locally.
- That snapshot is exposed to commands via the **`NIX_PATH`** env var
  (e.g. `nixpkgs=/nix/var/nix/profiles/.../channels/nixpkgs`).

So `nix-shell -p ripgrep` does:

```
nix-shell -p ripgrep
   │
   ├─ reads NIX_PATH  ──►  finds the "nixpkgs" entry
   │
   └─ uses whatever snapshot it points to RIGHT NOW
```

## Why channels aren't reproducible

The problem is the phrase **"right now."** A channel is mutable global state on
the machine:

1. **It drifts over time.** Update today → ripgrep 14.1. A teammate updated last
   month → 14.0. Same command, different binary. The command never encodes
   *which* version; it trusts the machine's current channel.
2. **It's per-machine.** Laptop, server, and CI each carry their own channel
   state, updated at different times. Nothing ties them together → "works on my
   machine" returns.
3. **Nothing is written down.** No file in your project records "I used nixpkgs
   at commit abc123." The version lives in ambient system state outside the repo,
   so you can't commit, review, or roll back to it.

Note: `nix-shell` still *builds* reproducibly in the narrow sense that a given
derivation always yields the same output. What's unpinned is **which derivation
you get** — its inputs are chosen by mutable machine state. Same command, two
machines, possibly different packages.

## How flakes fix it

A flake names nixpkgs as an explicit **input** and records the exact commit in
**`flake.lock`**:

```nix
inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
```

On first build, `flake.lock` pins this to a specific commit hash. From then on,
*any machine, any time* gets byte-identical nixpkgs until you deliberately run
`nix flake update`. The version moved **out of ambient machine state and into a
committed file in your repo**.

That's the whole difference:

- **Channels** answer "which nixpkgs?" with *the machine's current mood*.
- **Flakes** answer it with *a hash in a lockfile you can commit and review*.

## The flakes equivalent of `nix-shell -p`

```bash
nix shell nixpkgs#ripgrep      # rg on PATH until you exit the subshell
```

- `nixpkgs#ripgrep` is a **flake reference**: `nixpkgs` is the flake, `ripgrep`
  the output attribute (a package).
- `nixpkgs` is a built-in **registry alias**. By default it resolves to
  `github:NixOS/nixpkgs/nixpkgs-unstable` — **a branch, not a commit**.

Variations:

```bash
nix shell nixpkgs#ripgrep nixpkgs#fd        # multiple packages
nix run nixpkgs#ripgrep -- --version        # run once, no subshell
nix shell github:NixOS/nixpkgs/abc123#ripgrep   # pin an exact commit
```

| Old                                    | New                            |
|----------------------------------------|--------------------------------|
| `nix-shell -p ripgrep`                 | `nix shell nixpkgs#ripgrep`    |
| `nix-shell -p ripgrep --run 'rg foo'`  | `nix run nixpkgs#ripgrep -- foo` |

### Important: ad-hoc is NOT reproducible (either form)

`nix shell nixpkgs#ripgrep` is **not** meaningfully more reproducible than
`nix-shell -p ripgrep`. Both resolve against "current" nixpkgs and **neither
writes a lockfile**:

- the registry alias points at a *branch*, which resolves to "latest commit right
  now" (cached for `tarball-ttl`, default 1h);
- an ad-hoc CLI command produces no `flake.lock`, so nothing is pinned or
  recorded.

Different machine or different day → potentially a different `.drv`. No guarantee.

**Flakes don't make things reproducible by existing — the `flake.lock` does, and
a lockfile only exists for a flake you actually built/own.**

```
nix-shell -p ripgrep                → channel (NIX_PATH)      → no lock → floats
nix shell nixpkgs#ripgrep           → registry alias (branch) → no lock → floats
nix shell .#ripgrep                 → YOUR flake's flake.lock  → pinned  → reproducible
nix develop  (in a flake dir)       → YOUR flake's flake.lock  → pinned  → reproducible
this repo's homeConfigurations      → flake.lock               → pinned  → reproducible
```

This repo is reproducible *because* it has a committed `flake.lock` pinning
nixpkgs to a commit — not because it is "a flake." The bare `nixpkgs#…` shortcut
deliberately trades that pin for convenience.

To pin an ad-hoc command yourself:

```bash
nix shell github:NixOS/nixpkgs/<commit>#ripgrep   # explicit commit, fully pinned
nix registry pin nixpkgs                           # freeze the alias machine-wide
nix shell .#ripgrep                                # use your project's locked nixpkgs
```

## Practical rule

- `nix develop` — project/dev environments.
- `nix shell nixpkgs#x` — quick ad-hoc tools.
- Flakes — everything you actually maintain.
- Reach for `nix-shell`/channels only for legacy material (someone's old
  `shell.nix`, a throwaway where pinning doesn't matter).
