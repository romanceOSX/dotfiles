# Flake reference (flakeref) syntax

A flake reference has two parts:

```
<flake-reference>#<attribute-path>
└── which flake ──┘ └── which output ┘
```

The part before `#` says **where the flake lives**; the part after says **which
output to pick**. Both parts have defaults, so you often write less than the full
form.

## The flake location (before `#`)

A URL-like string whose leading scheme selects a fetcher:

| Form | Example | Notes |
|---|---|---|
| **indirect** (registry alias) | `nixpkgs`, `nixpkgs/nixos-24.11` | looked up in the flake registry; often a branch → floats (see `shells-and-channels.md`) |
| **github** | `github:NixOS/nixpkgs`, `github:NixOS/nixpkgs/nixos-unstable`, `github:owner/repo/<rev>` | 3rd segment is a branch/tag/**commit**; a commit = fully pinned |
| **gitlab / sourcehut** | `gitlab:owner/repo`, `sourcehut:~user/repo` | same shape as github |
| **git** | `git+https://…`, `git+ssh://git@host/repo`, `git+file:///abs/path` | any git remote or local repo |
| **path** | `path:/abs/path`, `.`, `./subdir`, `/abs/path` | a local directory; `.` = current dir |
| **tarball** | `https://…/x.tar.gz`, `tarball+https://…` | a fetched archive |

Refinements are URL query params:

```
github:NixOS/nixpkgs?ref=nixos-24.11      # branch/tag
github:NixOS/nixpkgs?rev=abc123…          # exact commit (pin)
git+https://example.com/repo?dir=sub      # flake lives in a subdirectory
git+ssh://git@host/repo?ref=main&rev=…    # combine
```

## The output selector (after `#`)

An **attribute path** into the flake's `outputs`:

```
nixpkgs#hello
.#myPackage
.#devShells.aarch64-darwin.default
github:owner/repo#packages.x86_64-linux.foo
```

Omit `#…`, or give just a short name, and Nix fills in the rest based on the
command + your current system, trying a prefix list:

| Command | Tries (`<system>` = your platform) |
|---|---|
| `nix build` / `nix shell` | `packages.<system>.<name>` → `legacyPackages.<system>.<name>` |
| `nix run` | `apps.<system>.<name>` → `packages.<system>.<name>` → `legacyPackages…` |
| `nix develop` | `devShells.<system>.<name>` → `packages.<system>.<name>` |

`<name>` defaults to `default` when omitted. So:
- `nix shell nixpkgs#ripgrep` → `nixpkgs#legacyPackages.<system>.ripgrep`
- `nix develop` (no fragment) → `.#devShells.<system>.default`

## Two equivalent representations

The same flakeref can be written as the URL string above, or as an **attrset**:

```
github:NixOS/nixpkgs  ≡  { type = "github"; owner = "NixOS"; repo = "nixpkgs"; }
```

You mostly write the string form on the CLI; the attrset form appears inside
`flake.nix` inputs and in `flake.lock`.

## Official documentation

- **Authoritative reference** — `nix3-flake` manual, "Flake references" section:
  <https://nixos.org/manual/nix/stable/command-ref/new-cli/nix3-flake>
  (locally: `man nix3-flake`, or `nix flake --help`)
- **Fetcher/input details** — `builtins.fetchTree`:
  <https://nixos.org/manual/nix/stable/language/builtins>
- **Per-command attr-path resolution** — each command's page, e.g.
  `man nix3-shell`, `man nix3-build`, or the new-cli index:
  <https://nixos.org/manual/nix/stable/command-ref/new-cli/nix>
- **Gentler tutorials** — <https://nix.dev> and the NixOS Wiki Flakes page:
  <https://wiki.nixos.org/wiki/Flakes>

# Anatomy of a minimal flake

```nix
{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs }: {
    packages.x86_64-linux = {
      default = self.packages.x86_64-linux.hello;
      hello   = nixpkgs.legacyPackages.x86_64-linux.hello;
    };
  };
}
```

## The whole file is one attribute set

A `flake.nix` evaluates to a single attrset with a fixed set of recognized keys —
`description`, `inputs`, `outputs`. That's the **flake schema**: Nix looks for
exactly these names.

## `inputs`

```nix
inputs = { nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable"; };
```

`nixpkgs.url = …` is dotted shorthand for `nixpkgs = { url = …; };`. Declares one
dependency named `nixpkgs`, fetched from that flakeref; pinned in `flake.lock` on
first build.

## `outputs` is a function, not a value

```nix
outputs = { self, nixpkgs }: { ... };
```

- `{ self, nixpkgs }` is the parameter — Nix's **destructuring** syntax for a
  function taking one attrset and pulling out the keys `self` and `nixpkgs`.
- `:` separates params from body.
- `{ ... }` is the attrset the function returns.

**Nix calls this function for you**, injecting an attrset where:
- `nixpkgs` = the fetched, locked nixpkgs input, *already evaluated to its
  outputs*;
- `self` = this flake's *own* final output set (a recursive handle).

The parameter names for your inputs must match the names in `inputs`; they are
injected, not read from any ambient scope.

## Why the returned attrset is shaped like that

The shape is a **contract** the CLI relies on:

```
packages              # category the CLI knows
  .x86_64-linux       # <system> partition (pure eval can't read the host)
    .default          # name `nix build` uses by default
    .hello            # name `nix build .#hello` uses
```

`nix build .#hello` looks up `outputs.packages.<system>.hello`; `nix build` (no
name) looks up `…packages.<system>.default`. Shape it differently and the CLI
finds nothing. You fill in a structure Nix defined; you don't invent one.

## Where did `packages` come from?

Nowhere — **you are defining it**, not reading it. `packages` is a *key you
create* in the returned attrset; it has meaning only because the CLI later looks
for a key by that name (like returning `{ status = 200; }` from a handler —
`status` isn't in scope, it's a field the framework expects). And

```nix
packages.x86_64-linux = { default = …; hello = …; };
```

is just dotted shorthand for

```nix
packages = { x86_64-linux = { default = …; hello = …; }; };
```

Everything here is being *built*, not looked up.

## Why `default` references `self`, and where `hello` is defined

`hello` is defined right there as a sibling: its value is
`nixpkgs.legacyPackages.x86_64-linux.hello` (the `hello` derivation from the
nixpkgs input). `default` is an **alias** to that same derivation.

Why `self.packages…hello` instead of just `hello`? Ordinary Nix attrsets are
**not recursive** — in `{ a = 1; b = a; }`, `b = a` fails (you'd need `rec`). So
`default = hello;` is illegal: `hello` is a sibling key, not a variable. `self`
sidesteps it: it's a function argument bound to the flake's *final* output set, so
`self.packages.x86_64-linux.hello` is a legal value lookup into the finished
outputs. It works because Nix is **lazy** — `self` is only forced when `default`
is actually demanded, by which point the output set is fully built. (You could
instead use `rec { … }` or a `let`; `self` is the conventional flake style and
reaches across the whole output tree.)

## `legacyPackages` vs `packages`

nixpkgs exposes its package set under `legacyPackages.<system>`, not
`packages.<system>`. The flake `packages` schema must be a *flat*
`<system>.<name>` map, but nixpkgs is a deeply nested hierarchy
(`python3Packages.numpy`, …) predating flakes. `legacyPackages` is the schema's
escape hatch for exactly that — so nixpkgs dumps everything there, which is why
you fetch `hello` from `nixpkgs.legacyPackages.x86_64-linux.hello`.
