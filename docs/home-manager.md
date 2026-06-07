# Home Manager

> The generic "what is a flake" notes that used to live here are now in
> `flake-references.md`. This file is about how Home Manager fits on top of
> flakes.

## Two contracts, stacked

The confusion to clear first: a Home Manager setup involves **two different
contracts**, layered.

```
┌─ FLAKE contract ──────────────────────────────────────────────┐
│ flake.nix: inputs { nixpkgs, home-manager }                    │
│            outputs → homeConfigurations.osx                     │
│                                                                 │
│   builds that output by calling:                                │
│   home-manager.lib.homeManagerConfiguration { pkgs; modules=[…]}│
│                                                                 │
│        ┌─ MODULE contract ───────────────────────────────────┐ │
│        │ ./home (default.nix + imports): { config,pkgs,... }: │ │
│        │   set options → programs.git.enable, home.packages…  │ │
│        └──────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

- **Flake contract** (outer) — *packaging/distribution*: `inputs` + `outputs`,
  pinned by `flake.lock`. `homeConfigurations.osx` is one output slot.
- **Module contract** (inner) — *configuration composition*: each module is a
  function `{ config, lib, pkgs, ... }: { ... }` that either `imports` other
  modules or **assigns option values** (`programs.git.enable = true`,
  `home.packages = [ … ]`). Home Manager *defines* those options; you *set* them.
  Same module system NixOS uses — "NixOS modules, but for a user's home dir."

You write the *module* contract in `home/*.nix`. You will never put
`inputs`/`outputs` inside `home/`.

## A module is not a flake

`home/default.nix` in this repo:

```nix
{ ... }:                          # a function (gets config/pkgs/lib/...)
{
  imports = [ ./packages.nix … ]; # compose other modules
  programs.home-manager.enable = true;   # SET an option value
  home.stateVersion = "24.11";
}
```

No `inputs`/`outputs` → not a flake. It's a **module**.

## The flake IS a normal flake (common misconception)

A `flake.nix` consumed by Home Manager is an ordinary flake. Specifically:

- It does **not** output modules. The modules (`./home`) are *input material*
  consumed internally; they never appear in `outputs`.
- It **does** ultimately produce a derivation — nested, exactly like
  `nixosConfigurations`.

The chain:

```
modules (./home/*)                      ← what you WRITE (module contract)
   │  fed into
   ▼
home-manager.lib.homeManagerConfiguration { pkgs; modules = […]; }
   │  produces
   ▼
homeConfigurations.osx                   ← the flake OUTPUT (normal slot)
   │  contains
   ▼
.activationPackage                       ← a DERIVATION (.drv → built → activated)
```

`home-manager switch --flake .#osx` reads `homeConfigurations.osx`, realises its
`activationPackage`, and runs that package's activation script (symlinks dotfiles
into `~`, puts packages on your profile, exports XDG dirs, etc.).

## What Home Manager actually *is*

As a flake input it ships two things:

1. a **library function** — `home-manager.lib.homeManagerConfiguration` — that
   turns a list of modules into a buildable configuration;
2. a large **set of modules/options** (`programs.*`, `home.*`, `xdg.*`, …) that
   you configure.

So it bridges the two contracts: it takes **modules** in and exposes a
**derivation** (via a flake output) out.

## Does it take "any" flake?

No — it takes **modules**, not flakes. The contract you follow is the *module*
contract, not the flake schema.

The one meeting point: another project can *distribute* a reusable Home Manager
module as a flake output named `homeManagerModules.foo`. But what HM consumes is
still the **module** you pull out of that output and drop into your
`modules = [ … ]` / `imports = [ … ]` list. The flake is the delivery truck; the
module is the cargo.

Three flake roles around Home Manager (all ordinary flakes, different slots):

| Role | Output slot | Example |
|---|---|---|
| consumer / config (this repo) | `homeConfigurations.<name>` | `homeConfigurations.osx` |
| module publisher | `homeManagerModules.<name>` | a tool shipping its own HM module |
| Home Manager itself | `lib` + modules | `home-manager.lib.…` |

## Why this flake doesn't follow the `packages` shape

`packages.<system>.<name>` was never *the* required shape of a flake — it's just
**one well-known output slot**, and `outputs` is otherwise a free-form attrset.

### `outputs` is open, not a fixed schema

`outputs` may return any attributes. Nothing forces them into `packages`. There's
only a set of **conventional slot names** that *tools* agree to look for:

```nix
outputs = {
  packages.<system>.<name>   = …;   # well-known
  devShells.<system>.<name>  = …;   # well-known
  nixosConfigurations.<name> = …;   # well-known (different shape!)
  homeConfigurations.<name>  = …;   # well-known (different shape!)
  myWeirdThing               = …;   # allowed; just no tool reads it
};
```

`nix flake show` / `nix flake check` recognize the standard names and type-check
those; **unknown outputs are allowed** (shown as "unknown", not rejected).

### The shape is a contract *per slot*, between producer and a specific consumer

Not one global law — each slot has its own expected shape, enforced by whichever
**consumer** reads it:

| Output slot | Shape | Consumer / enforcer |
|---|---|---|
| `packages.<system>.<name>` | derivation | `nix build` / `nix shell` |
| `devShells.<system>.<name>` | derivation | `nix develop` |
| `nixosConfigurations.<name>` | config obj (`.config.system.build.toplevel`) | `nixos-rebuild` |
| `homeConfigurations.<name>` | config obj (`.activationPackage`) | the `home-manager` CLI |

This flake "doesn't follow the packages shape" simply because it isn't talking to
`nix build` — it talks to `home-manager`, which defines a *different* slot.

### Why `homeConfigurations` is keyed by *name*, not `<system>`

Per-system slots need a `<system>` level because pure evaluation can't read the
host. `homeConfigurations` sidesteps that by **encoding the system inside the
config**:

```nix
"osx" = mkHome {
  system = "aarch64-darwin";    # ← system specified HERE, internally
  username = "romance";
  homeDirectory = "/Users/romance";
};
```

`mkHome` feeds that into `import nixpkgs { system = …; }` and the HM module sets
the platform, so the target is baked into the config object. No `<system>` key
needed → the slot is `homeConfigurations.<name>` (a name *you* choose, like
`osx`).

### Is this distinction documented?

There's no single rigorous spec — part of why it's confusing.

- **Outputs Nix itself recognizes + their shapes** — the `nix flake check`
  reference enumerates `packages`, `devShells`, `apps`, `checks`,
  `nixosConfigurations`, `nixosModules`, `overlays`, `formatter`, `templates`, …:
  <https://nixos.org/manual/nix/stable/command-ref/new-cli/nix3-flake-check>
- **Outputs is open / free-form** (unknown attrs allowed):
  <https://nixos.org/manual/nix/stable/command-ref/new-cli/nix3-flake>
- **`homeConfigurations`** is *not* Nix-recognized — defined/consumed by Home
  Manager, documented in the HM manual's flakes section (with
  `homeManagerConfiguration`): <https://nix-community.github.io/home-manager/>
- **Community catalog** of conventional names:
  <https://wiki.nixos.org/wiki/Flakes>
- **Formalization effort** (the gap is acknowledged): Determinate Systems'
  `flake-schemas`: <https://github.com/DeterminateSystems/flake-schemas>

Takeaway: Nix documents the slots *it* understands; every other tool
(`home-manager`, `nixos-rebuild`) documents *its own*. No central registry — which
is what `flake-schemas` aims to fix.

## Where to find options / how to write configs

Every `programs.*` / `home.*` attribute in `home/*.nix` is a documented option.

### 1. The options reference (primary)

- **Online:** <https://nix-community.github.io/home-manager/options.xhtml> —
  search e.g. `programs.zsh.shellAliases`, `home.sessionVariables`. Each entry
  gives type, default, example, and a "Declared by" link to the source module.
- **Offline man page:** `man home-configuration.nix`
- **Offline, per-option (fastest):** `home-manager option <name>`
  ```bash
  home-manager option programs.zsh.shellAliases
  home-manager option programs.zsh            # whole subtree
  home-manager option home.sessionPath
  ```

### 2. The manual (narrative / how-to)

<https://nix-community.github.io/home-manager/> — install, flake setup, writing
config, the module system, and **release notes** (the stateVersion-gated default
changes — e.g. `neovim.withRuby`, `zsh.dotDir` — are documented there). Also
`man home-manager`.

### 3. Reading the module source

For behavior the option text doesn't spell out (e.g. *when* `initContent` is
sourced vs `compinit`), read the module that *declares* the option — the
"Declared by" link, or the home-manager repo under `modules/programs/<name>.nix`:

- `modules/programs/zsh.nix` — `enable`, `shellAliases`, `history`, `plugins`,
  `initContent`, `profileExtra`, `completionInit`
- `modules/programs/fzf.nix`, `modules/programs/starship.nix`
- `modules/home-environment.nix` — `home.sessionVariables`, `home.sessionPath`,
  `home.stateVersion`

### 4. The `lib.*` / `builtins.*` glue (not HM-specific)

The non-option code in a module comes from elsewhere:

| Code | What | Docs |
|---|---|---|
| `lib.optionalString`, `lib.optionalAttrs`, `lib.optionals`, `lib.concatStringsSep` | nixpkgs lib functions | **noogle.dev** + Nixpkgs manual |
| `pkgs.stdenv.isLinux` / `isDarwin`, `pkgs.zsh-fzf-tab` | nixpkgs packages/stdenv | Nixpkgs manual; search.nixos.org |
| `builtins.fromTOML`, `builtins.readFile` | Nix language builtins | <https://nixos.org/manual/nix/stable/language/builtins> |
| `{ pkgs, lib, config, ... }:`, `config.home.homeDirectory` | module system | HM manual + NixOS module docs |

- **noogle.dev** — <https://noogle.dev> — searchable `lib`/`builtins` reference.

### 5. Community search

- **<https://mynixos.com>** — indexes HM *and* NixOS options + packages together.
- **<https://search.nixos.org>** — packages (for `home.packages`) + NixOS options.

### Practical workflow for editing a module

1. `home-manager option programs.<thing>` (or the online appendix) for the exact
   option name/type.
2. If behavior is unclear, open its "Declared by" source module.
3. For `lib.*`/`builtins.*` glue, hit noogle.dev.
4. `home-manager build --flake .#osx` to type-check *before* switching — it errors
   on bad option names/types without activating.

## Mental model

- **Flake** = how code is *packaged and pinned* (inputs/outputs). Outer layer.
- **Module** = how configuration is *declared and merged* (options/config). Inner
  layer, and what you write for Home Manager.
- Home Manager bridges them: its `lib` function turns a list of **modules** into a
  buildable **derivation**, exposed as the flake output
  `homeConfigurations.<name>`, whose `activationPackage` is what gets built and
  activated.
