# Nix concepts (for developers starting out)

The Nix world is four distinct things that get conflated. Untangling them first
makes everything else click.

## The four pieces

```
Nix package manager  = the build engine + immutable store
Nix language         = how you write build descriptions for the engine
Flakes               = standardized, version-locked packaging format
NixOS                = the whole engine pointed at "an entire OS"
```

### Nix package manager

The foundation. A package manager (like `apt`/`brew`) built on one idea: every
package is built in isolation and stored at an immutable path keyed by a hash of
*all its inputs* (source, dependencies, build flags, compiler version). Paths
look like `/nix/store/qvxqyq2z93w0nns10pnfjmfj4snrln1y-...`.

Consequences:
- Two versions/configs of the same package coexist (different hash → different
  path). No dependency hell.
- Builds are reproducible: same inputs → same output path.
- Install / upgrade / rollback are atomic (flip a symlink).

This is the actual engine. Everything else layers on top.

### The Nix language

The engine needs you to *describe* what to build. A `.nix` file is a program
that evaluates to a data structure called a **derivation** — a description of a
build: its inputs, build steps, and outputs. The language's whole job is
"produce build descriptions."

### NixOS

The same idea applied to an *entire operating system* (Linux only). You write
one declarative config for the whole machine (kernel, services, users, packages,
firewall) and Nix builds the system into the store. Atomic upgrades, rollback to
a previous "generation" at boot.

> **home-manager** (what this repo uses) is the same idea scoped to a *user's*
> environment/dotfiles instead of the whole OS — and it works on macOS too,
> which is why we use it instead of NixOS.

### Flakes

A newer packaging/distribution standard on top of everything above. A flake is a
directory with a `flake.nix` following a standard schema:
- typed **`inputs`** — other flakes/repos, version-pinned in `flake.lock`
- **`outputs`** — packages, configs, dev shells

Before flakes, Nix pulled dependencies from ambient global state (`NIX_PATH`,
channels) — implicit and non-reproducible. Flakes make inputs explicit and
locked, like `package.json` + `package-lock.json`. This repo's `flake.nix` is
exactly this: `inputs` (nixpkgs, home-manager) → `outputs`
(`homeConfigurations.osx`, etc.).

## Derivations (and why "same command" ≠ "same derivation")

A **derivation** is the precise, fully-resolved build recipe — the low-level
thing the Nix *language* produces. Three layers:

```
expression / command   →   derivation (.drv)   →   output (/nix/store/...-ripgrep-14.1)
   "I want ripgrep"         the exact recipe         the actual built binary
   (high-level wish)        (every input pinned      (content-addressed by
                             by store path/hash)      the derivation's inputs)
```

- A derivation is an actual file in the store, e.g.
  `/nix/store/xxxx-ripgrep-14.1.drv`. It spells out *everything* concretely: the
  build script, env vars, and **each input by its full store path** (this gcc at
  `/nix/store/aaa…`, this openssl at `/nix/store/bbb…`, this source with this
  hash).
- It's the result of **evaluation** — running the Nix language. The language is
  your high-level wish ("ripgrep"); evaluation resolves it into a concrete `.drv`
  where nothing is ambiguous anymore.
- **Realization** then executes the `.drv` to produce the output. A `.drv` is
  itself hashed by its inputs, and the same `.drv` *always* realizes to the same
  output.

### Why "same command" ≠ "same derivation"

Key to the channel/reproducibility confusion (see `shells-and-channels.md`):

> Two identical derivations DO produce identical outputs. Always.

The non-reproducibility is **not** at the derivation level — it's *upstream*, at
the moment the derivation is **created**.

`nix-shell -p ripgrep` is **not a derivation**; it's a command/expression. Before
anything builds, Nix must *evaluate* it into a `.drv`, which means looking up
which gcc, which openssl, which ripgrep source — in nixpkgs. With channels, that
lookup uses the machine's **current snapshot**:

```
nix-shell -p ripgrep  ─(evaluate against CHANNEL A)→  drv-A  →  ripgrep-14.1
nix-shell -p ripgrep  ─(evaluate against CHANNEL B)→  drv-B  →  ripgrep-14.0
       same command           different snapshot      different .drv   different binary
```

You never get "two exact derivations" across those machines — you get *two
different* `.drv` files, because the same command was evaluated against different
inputs. Once a `.drv` exists, reproducibility is airtight; the leak is purely in
*how the `.drv` is generated*. Flakes plug it by pinning the snapshot
(`flake.lock`), so the same command always evaluates to the same `.drv`.

Analogy: the derivation is the fully-pinned, lockfile-resolved build plan; the
command is your high-level request (`"ripgrep"`, like `^14`); the channel/flake
is the index you resolve it against. `nix-shell` resolves against a moving index;
flakes resolve against a committed lockfile.

## The formal pipeline: instantiate → realise

"Realisation" (Nix uses the British spelling) is a *formal, named step*, not
casual wording. There are two precise verbs, mapping onto the two phases:

```
Nix expression ──instantiate──► store derivation (.drv) ──realise──► output store paths
                (nix-instantiate)                          (nix-store --realise)
```

1. **Instantiation** — translate a Nix *expression* into a **store derivation**
   (the `.drv` written into the store). Command: `nix-instantiate`. This is the
   formal name for "evaluation → derivation."
2. **Realisation** — ensure a derivation's **output store paths exist**. Command:
   `nix-store --realise` (`nix-store -r`). It can be satisfied two ways:
   - **building** the derivation locally, or
   - **substituting** — downloading the prebuilt output from a binary cache.

   Both count as realising. (This is why an `x86_64-linux` drv can be "realised"
   on a Mac by *substitution* from a cache, without a local build.)

Definition: *to realise a store path is to ensure the store object it names is
present in the store* — by build, substitute, or copy.

> Narrower second meaning: in **content-addressed derivations** (experimental),
> a "realisation" is also a concrete record mapping an output id
> (`drvpath!output`) to the actual content-addressed store path + hash, exchanged
> between caches. You only meet this once you touch CA derivations.

The newer unified CLI folds both steps into `nix build` etc., but these glossary
terms stay the canonical vocabulary. Formal docs:

- Glossary (*derivation*, *instantiate*, *realise*, *substitute*, *store object*):
  <https://nixos.org/manual/nix/stable/glossary>
- `nix-store --realise`:
  <https://nixos.org/manual/nix/stable/command-ref/nix-store/realise> (`man nix-store`)
- `nix-instantiate`:
  <https://nixos.org/manual/nix/stable/command-ref/nix-instantiate>

Anchor: **instantiate = expression → `.drv`; realise = `.drv` → outputs (build
*or* download).**

## Front-end vs engine: nix-shell, flakes, derivations

Flakes are **not** an alternative to derivations — they're a different *front-end*
that produces derivations. The derivation layer, the build engine, and the store
are *identical* for both. They differ only in how they resolve inputs *before* the
derivation exists.

```
            ┌─ resolves inputs ─┐
nix-shell ──┤  via NIX_PATH /    ├─►  derivation (.drv) ─►  build engine ─►  /nix/store/...
            │  channels (mutable)│         ▲                  (identical       (identical
flakes    ──┤  via flake.nix +   ├─────────┘                   for both)        for both)
            │  flake.lock (pinned)│
            └────────────────────┘
```

Everything to the *right* of the `.drv` is the same machinery. The only
difference is to the *left*: `nix-shell` picks `<nixpkgs>` from ambient machine
state (`NIX_PATH`/channels, unrecorded); flakes pick inputs from
`flake.nix` + `flake.lock` (recorded commit hashes).

### Do two flakes on different machines produce the same derivation?

Yes — given two conditions:

1. **Same `flake.lock`.** The lock pins nixpkgs to a commit; both machines then
   evaluate against byte-identical source → identical `.drv` → identical store
   path. (If one ran `nix flake update`, the locks differ, so the derivations do
   too.)
2. **Same target `system`.** A derivation includes its target platform as an
   input, so `packages.x86_64-linux.ripgrep` and `packages.aarch64-darwin.ripgrep`
   are *different* derivations.

The machine *doing the evaluating* is **not** an input — only the locked inputs +
target system are. So you can evaluate the `x86_64-linux` derivation on a Mac and
on a Linux box and get the **byte-identical `.drv`**.

Caveats that break the guarantee: impurity escape hatches — `--impure`,
`builtins.getEnv`, reading untracked files, time/randomness. Pure flake evaluation
forbids these, which is *why* it can promise the same `.drv`.

### Two separate "reproducibility" claims

- **Same `.drv` / same store path** (evaluation reproducibility) — guaranteed by
  `flake.lock` + same system. Store paths come from *inputs*, not output bytes.
- **Bit-for-bit identical output** (build reproducibility) — depends on whether
  the package's *build* is deterministic (most are; a few embed timestamps). This
  is a property of the package, not of flakes vs nix-shell.

### Same `.drv` ≠ runnable/buildable anywhere

Evaluating an `x86_64-linux` derivation on a Mac gives the identical `.drv`, but:

- **Running it:** the output is a Linux binary (Linux syscall ABI) — macOS can't
  execute it (Rosetta only covers `x86_64-darwin`, not Linux). You'd need a Linux
  VM/container.
- **Building (realizing) it:** realization needs a builder matching the
  derivation's `system`. On a Mac you'd hit
  `a 'x86_64-linux' ... is required to build ..., but I am a 'aarch64-darwin'`.
  Options: a remote Linux builder, the nix-darwin `linux-builder` VM, emulation
  (binfmt/qemu), or just substitute (download) it from a binary cache.

Evaluation is pure and host-independent; realization and execution require a host
matching the derivation's `system`.

### The `<system>` field

Two layers:

1. **The system double is core Nix, not flake-specific.** Every derivation has a
   mandatory `system` attribute — a "system double" like `x86_64-linux`,
   `aarch64-darwin`, `x86_64-darwin`. It's an input to the derivation hash (so
   platform changes the `.drv`). Outside flakes, code reads the host value via the
   impure `builtins.currentSystem`.
2. **Keying outputs by `<system>` is the flake output schema.** Flake evaluation
   is *pure* and forbidden from reading `builtins.currentSystem` — it can't know
   which machine will consume it. So a flake must enumerate outputs per system:

   ```nix
   outputs = {
     packages.x86_64-linux.foo  = …;
     packages.aarch64-darwin.foo = …;
   };
   ```

   The shape `packages.<system>.<name>`, `devShells.<system>.<name>`, etc. is the
   contract the `nix` CLI relies on; it fills `<system>` from *your host's* double
   and looks up that branch. This per-system boilerplate is why helpers like
   `flake-utils.lib.eachDefaultSystem` / a `forAllSystems` function exist — to
   generate those attrsets.

### `<system>` is just an output attribute key

`<system>` is not a special field — it's one level of keys in the `outputs`
attrset, the same kind of plain attribute name as `hello`:

```
outputs
└── packages              ← category (packages / devShells / apps / …)
    ├── x86_64-linux      ← a <system> key (just a string attribute name)
    │   ├── hello
    │   └── ripgrep
    └── aarch64-darwin    ← another <system> key
        ├── hello
        └── ripgrep
```

It's "special" only by convention: (1) the schema partitions outputs by system at
that level, and (2) the CLI auto-substitutes *your host's* double into the
`<system>` slot. Consequences:

- **Which systems exist is the author's choice.** A flake defining only
  `packages.x86_64-linux` makes `nix build` on a Mac fail with "does not provide
  attribute `packages.aarch64-darwin…`" — there's simply no key there.
- **It's a partition, not a toggle.** Each system is its own independent subtree,
  evaluated purely; you don't "configure `<system>`". Authors usually *generate*
  the subtrees (`eachDefaultSystem` / `forAllSystems`) rather than hand-write each.
- You can always address it explicitly:
  `nix build .#packages.x86_64-linux.hello` bypasses the auto-fill.

## What an output value actually is (and how it becomes a `.drv`)

For `packages`/`devShells`/etc., the output value **already is a derivation** —
the `.drv` was written to the store the moment that value was evaluated. There is
no separate "convert output → drv" step.

### A flake's `outputs` is a function returning an attrset

```nix
outputs = { self, nixpkgs, ... }: {
  packages.x86_64-linux.hello = ...;   # ← what type is this leaf?
};
```

Calling `outputs` yields a nested attrset; the CLI navigates it by path
(`packages.<system>.hello`). The interesting part is the *leaf's* type.

### In the Nix language, a "derivation" is a tagged attrset

`pkgs.hello` (ultimately the `derivation` builtin) evaluates to an attrset with a
special shape:

```nix
{
  type    = "derivation";          # the tag marking it a derivation
  name    = "hello-2.12.1";
  system  = "x86_64-linux";        # baked in — this is where <system> lives
  drvPath = "/nix/store/xxxx-hello-2.12.1.drv";   # the .drv file
  outPath = "/nix/store/yyyy-hello-2.12.1";       # predicted output path
  out     = { ... };               # the output(s)
}
```

That's the type: a derivation **is** an attrset, marked by `type = "derivation"`
plus `drvPath`/`outPath`. Inspect it:

```bash
nix eval .#packages.x86_64-linux.hello.type            # "derivation"
nix eval --raw .#packages.x86_64-linux.hello.drvPath   # /nix/store/...-hello.drv
nix eval --raw .#packages.x86_64-linux.hello.outPath   # /nix/store/...-hello
```

### When the `.drv` is written: on force, during evaluation

The `.drv` is created **as a side effect of forcing the value** — this *is*
instantiation. The `derivation` builtin computes the `.drv` from its inputs,
writes `/nix/store/…-hello.drv`, and sets `drvPath`. `outPath` is computed at the
same time (input-addressed: a hash of all inputs), which is how Nix knows the
output path *before* building. Flow for `nix build .#hello`:

```
call outputs{}  →  attrset
  └─ select packages.<system>.hello  →  a derivation value
       └─ force it  →  .drv written to store          (INSTANTIATION)
            └─ read drvPath, realise it  →  output     (REALISATION)
```

No conversion step: the output value carries its own `drvPath`; the CLI reads it
and realises it.

### Where `<system>` enters

Selecting the `x86_64-linux` branch picks a leaf *constructed* for that system:

```nix
let pkgs = import nixpkgs { system = "x86_64-linux"; };
in { packages.x86_64-linux.hello = pkgs.hello; }
```

`pkgs.hello` uses the linux stdenv/compilers and sets `system = "x86_64-linux"`,
so the system is baked into the derivation's inputs → it instantiates to a Linux
`.drv`. The `aarch64-darwin` branch forces a *different* derivation value (darwin
toolchain) → a different `.drv`.

### Not every output is a derivation — type depends on the schema slot

| Output slot | Leaf type |
|---|---|
| `packages.<sys>.<name>` | a **derivation** |
| `devShells.<sys>.<name>` | a **derivation** (shell-env from `mkShell`) |
| `checks.<sys>.<name>` | a **derivation** |
| `apps.<sys>.<name>` | **not** a derivation — `{ type = "app"; program = "/nix/store/…/bin/x"; }` |
| `nixosConfigurations.<name>` | config object; derivation nested at `.config.system.build.toplevel` |
| `homeConfigurations.<name>` | config object; derivation at `.activationPackage` |
| `lib`, `overlays`, `nixosModules`, `templates`, `formatter` | arbitrary values/functions — not derivations |

Commands know per-slot *where* to find a derivation: `nix build
.#nixosConfigurations.foo` realises `.config.system.build.toplevel`, not the
config attrset itself. This repo's `homeConfigurations.osx` is the same pattern —
the buildable derivation is its `activationPackage`.

Anchor: **a derivation is a value (a tagged attrset whose `drvPath` names a `.drv`
already written to the store); a flake output is just where that value sits in the
outputs attrset.** Realisation then takes the `.drv` to a built output.

## What shape a derivation has (value vs `.drv`)

A derivation has **two distinct shapes**, at two layers — people conflate them.

### 1. The derivation *value* (Nix language level)

Everything bottoms out in the primitive `builtins.derivation`, which has a fixed
required shape — exactly three mandatory attributes:

| Attribute | Type | Meaning |
|---|---|---|
| `name` | string | the derivation/package name |
| `system` | string | system double (`x86_64-linux`, …) |
| `builder` | path/string | the executable that runs the build |

Optional *special* keys it understands: `args` (builder arguments), `outputs`
(output names, default `["out"]`), and advanced ones (`__structuredAttrs`,
`outputHash*` for fixed-output, `allowedReferences`, `preferLocalBuild`, …).
**Every other attribute you pass becomes an environment variable** in the build
sandbox (after string coercion). So the input shape is "a few reserved keys +
arbitrary keys → env vars."

What `derivation` *returns* is the tagged attrset, also a fixed shape:

```nix
{
  type       = "derivation";
  name       = "hello-2.12.1";
  system     = "x86_64-linux";
  builder    = "...";
  args       = [ … ];
  outputs    = [ "out" ];
  drvPath    = "/nix/store/…-hello.drv";
  outPath    = "/nix/store/…-hello";   # = .out.outPath
  outputName = "out";
  out        = { /* a derivation attrset for the `out` output */ };
  all        = [ … ];                  # all outputs
  # ...plus your custom attrs (the env vars)
}
```

> `stdenv.mkDerivation` is a higher-level *nixpkgs* wrapper adding `meta`,
> `passthru`, `override`, `overrideAttrs`, build phases, etc. — but it bottoms out
> in `builtins.derivation`. It's a richer convention on top of the fixed
> primitive shape, not a different shape.

### 2. The `.drv` store derivation (on-disk level)

The strict, formal one. On instantiation the derivation is serialized to a `.drv`
in ATerm format with exactly **seven fields**:

```
Derive(
  outputs,    # [(name, storePath, hashAlgo, hash)]  — hashes empty for input-addressed
  inputDrvs,  # [(drvPath, [outputNames])]           — dependencies that are derivations
  inputSrcs,  # [storePath]                           — plain source paths used
  system,     # "x86_64-linux"
  builder,    # "/nix/store/…/bin/bash"
  args,       # ["-e", "builder.sh"]
  env         # [(key, value), …]                     — the env vars
)
```

This structure is fixed and canonical — it's what the input hash (and thus the
store path) is computed from. Dump it as JSON to see it concretely:

```bash
nix derivation show .#hello      # (older: nix show-derivation)
```

→ exactly those fields: `outputs`, `inputSrcs`, `inputDrvs`, `system`, `builder`,
`args`, `env`.

### Summary

- **Strict at the `.drv` level** — a 7-field formal structure Nix defines and
  hashes. This is *the* canonical derivation shape.
- **Fixed-with-flexibility at the value level** — `name`/`system`/`builder`
  required, returns a `type="derivation"` attrset with `drvPath`/`outPath`/
  per-output attrs; extra attrs are free-form → env vars.
- `mkDerivation` is a convention-rich wrapper, not a new shape.

Docs: the `derivation` builtin + attributes —
<https://nixos.org/manual/nix/stable/language/derivations>; store-derivation /
glossary — <https://nixos.org/manual/nix/stable/glossary> (*derivation*, *store
derivation*) plus the `nix derivation show` reference.

## What "pure" actually means

A flake's philosophy: **evaluation reads nothing that isn't declared and locked.**
Purity is *not* about the command line — it's about evaluation depending only on
declared inputs, never on hidden/ambient state. Off-limits during evaluation:

- channels / `NIX_PATH`
- environment variables (`builtins.getEnv`)
- current time, randomness, the network (beyond declared inputs)
- untracked files (e.g. a gitignored `local.nix`)
- `builtins.currentSystem` (the host)

If an output can't depend on any of that, it's a pure function of its inputs →
same inputs always yield the same result. That's the entire definition.

**The explicitness lives in files, not the CLI:**

```
flake.nix   →  WHICH inputs (github:NixOS/nixpkgs, …)
flake.lock  →  exactly WHICH COMMIT of each (the pin)
```

That committed, reviewable pin is the explicitness; the command line mostly just
says *which output* you want, not what the inputs are.

**The `<system>` subtlety:** picking `<system>` at the CLI doesn't break purity,
because the flake purely computes outputs for *all* supported systems first, and
the CLI merely *selects* an already-computed branch. The host is a selector
applied *after* evaluation, not an input *to* it — which is why CLI `<system>`
selection is allowed while `builtins.currentSystem` is forbidden.

Tightened one-liner: *a flake doesn't read ambient state during evaluation;
inputs are declared in `flake.nix` and pinned in `flake.lock`, so outputs are a
function of locked inputs alone.*

## Why a separate language instead of Lua/Python?

The language's purpose is fundamentally different from a scripting language, and
reusing a general-purpose one would break the core guarantee.

1. **Purity is enforced by the language.** The value proposition is "same inputs
   → same output, always." A general scripting language can read the clock, hit
   the network, read env vars, mutate globals — any of which makes a build
   non-reproducible. Nix is purely functional with no side effects *by design*,
   so a build description literally cannot secretly depend on hidden state.
   (This is also why a flake can't read a gitignored `local.nix` — evaluation is
   sandboxed from ambient files.)

2. **It's a DSL for one data structure.** Nix programs don't "do things"; they
   evaluate to a derivation (a build graph). Think "JSON with functions and lazy
   evaluation" — closer to Dhall/Jsonnet/HCL than to Lua.

3. **Laziness is load-bearing.** nixpkgs describes ~100,000 packages. You
   evaluate a config that *references* all of them but only compute the parts you
   use. That needs lazy evaluation as a language primitive; Lua/Python are eager
   and would compute the whole universe to install one thing.

A sandboxed Lua subset was possible in theory, but you'd fight the host
language's eagerness and impurity constantly. They built the guarantees *into*
the language instead. (Whether that was the right call is an ongoing community
debate — the language is widely seen as Nix's weakest part.)

## Is it compiled? Performance? Why functional?

**Interpreted, not compiled.** A C++ evaluator reads `.nix` files and evaluates
them. Two distinct phases:
- **Evaluation** — running the Nix language to produce the build graph
  (interpreter doing functional work).
- **Build / realization** — actually executing the derivations (compiling C,
  running `make`) in a sandbox. Just normal processes; speed here is your
  compilers, not Nix.

**Performance:** the evaluator is the slow part and a known pain point —
evaluating large configs can take seconds to minutes and a lot of RAM (lazy
interpreted functional eval over a huge graph). Actively being improved (the
`lix` fork, bytecode evaluator). But:
- Evaluation cost is mostly irrelevant to runtime — a built program is a normal
  binary in the store with zero overhead.
- Builds are cached aggressively: if an input hash matches something already in
  the store or a binary cache (cache.nixos.org), it's downloaded or skipped, not
  rebuilt. This caching is the real performance story and it's excellent.

**Why functional / "weird":**
- **Functional** falls out of purity: no side effects → no statements, no
  mutation, no imperative loops. Everything is an expression that evaluates to a
  value.
- The "weird" feel is mostly lazy evaluation + everything-is-an-expression + the
  dominance of **attribute sets** (its dict/record type:
  `{ a = 1; b = 2; }`, basically JSON objects). `inherit (local) username
  homeDirectory;` is just shorthand for
  `username = local.username; homeDirectory = local.homeDirectory;`.

One-liner to internalize: **a Nix expression is a pure function from inputs to a
build graph, and the package manager then realizes that graph into an immutable,
content-addressed store.** Flakes, NixOS, and home-manager are just different
shapes of input feeding that same machine.

## Does one changed option mean a whole separate binary in the store?

Yes — and this is the model working as intended, not a bug.

Changing *any* build input (a flag, a dependency version, the source) changes the
derivation's input hash, which produces a new `/nix/store/...` path. So two
builds of the same program that differ by one option are two complete, separate
outputs living side by side. That's exactly what lets multiple versions/configs
coexist without conflict.

But it's less wasteful than it sounds:

- **Only changed closures differ.** Unchanged dependencies are *shared*. If you
  rebuild program X with one new flag, X gets a new path, but its libc, openssl,
  etc. — if their inputs didn't change — keep the *same* store paths and are not
  duplicated. The store deduplicates by input hash.

- **Downstream rebuilds propagate.** If the thing you changed is a dependency
  many packages share (say a libc build flag), everything depending on it gets a
  new hash too — this is the dreaded "rebuild the world." Changing a leaf package
  only rebuilds that leaf.

- **Disk cost is real but managed.** Extra copies do cost disk. Nix reclaims it
  with garbage collection (`nix-store --gc` / `nix store gc`), which deletes
  store paths no longer referenced by any installed profile/generation. Until you
  GC, old generations are retained on purpose — that's what makes rollback work.
- **Optional dedup:** the store can hard-link identical files across paths
  (`nix store optimise`) to cut the overhead of byte-identical files.

Mental model: the store trades disk space for correctness, isolation, and
instant rollback. You spend cheap disk to never have a broken or
irreproducible environment.

---

## Flake inputs, `flake.lock`, and `nix flake update`

`home-manager switch --flake .#osx` (or any `nix` command that builds a flake)
reads `flake.lock` and fetches **exactly the commit pinned there** for every
input. It never checks whether newer commits exist upstream — the lock file is
the source of truth for reproducibility.

So if you push a new commit to a flake input (e.g. your `nvim-config` repo), then
run `home-manager switch`, you get the **old** commit. The new one is invisible
until the lock is advanced.

**`nix flake update <input>`** is the explicit "advance this pin" step. It
rewrites the relevant entry in `flake.lock` to the current upstream `HEAD`, after
which `home-manager switch` picks it up.

```sh
# Update a single input and rebuild:
nix flake update nvim-config && home-manager switch --flake .#osx

# Update all inputs at once:
nix flake update && home-manager switch --flake .#osx
```

The two commands are intentionally separate so that `home-manager switch` is
always deterministic — two machines running it from the same `flake.lock` produce
identical results regardless of what was pushed upstream in the meantime.

### Home Manager + read-only config files

When HM manages a config directory (e.g. `~/.config/nvim/lua`), it deploys it as
a **symlink into the Nix store**, which is immutable. Any local edits or deletions
are silently overwritten on the next `home-manager switch`.

To iterate locally without pushing:

```nix
# flake.nix — point the input at a local path
nvim-config = {
  url = "path:/Users/romance/path/to/local/init.lua";
  flake = false;
};
```

`home-manager switch` then picks up local changes immediately. Revert the `url`
to the GitHub form and commit `flake.lock` when done.
