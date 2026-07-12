## Answered Questions

### How do `.nix` files / flakes import other flakes or modules?

Flakes declare dependencies in the `inputs` attrset in `flake.nix`. Each input is a URL
(GitHub, local path, etc.) that gets resolved and pinned to a commit in `flake.lock`.

```nix
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  home-manager = {
    url = "github:nix-community/home-manager";
    inputs.nixpkgs.follows = "nixpkgs";  # reuse the same nixpkgs instead of fetching a second one
  };
  some-source = {
    url = "github:user/repo";
    flake = false;  # fetch as a plain file tree, not as a flake
  };
};
```

Those inputs are then passed as arguments to the `outputs` function:

```nix
outputs = { nixpkgs, home-manager, some-source, ... }: { ... };
```

Modules (`.nix` files within the same repo) are imported with a plain path:

```nix
modules = [ ./home ./home/programs.nix ];
```

A directory path like `./home` is shorthand for `./home/default.nix` — Nix resolves it
automatically. Modules in the Nix module system (`home-manager`, `NixOS`) use `imports = [ ... ]`
inside each file to compose further.

---

### How can I use flakes from the command line — the `ref` syntax?

The general form is:

```
nix <command> <flake-ref>#<output-path>
```

`<flake-ref>` examples:

| Syntax | Meaning |
|---|---|
| `.` | the flake in the current directory |
| `/path/to/dir` | a local path |
| `github:user/repo` | latest default branch |
| `github:user/repo/branch-or-tag` | specific branch or tag |
| `github:user/repo/abc1234` | pinned to a commit |
| `git+https://...` | arbitrary git remote |
| `path:../other` | relative local path |

`#<output-path>` selects which output, e.g.:

```bash
home-manager switch --flake .#osx
nix build github:user/repo#somePackage
nix run github:user/repo/main#cli-tool
nix shell github:user/repo#dev
nix develop .#devShells.x86_64-linux.default
```

If you omit `#...`, `nix build` defaults to `packages.<system>.default`.

---

### How do people share home-manager configs across machines with different usernames/paths?

The common pattern (what this repo uses) is a small machine-local file (`local.nix`, gitignored)
that supplies the identity values the shared config doesn't know:

```nix
# local.nix (gitignored, each machine writes its own)
{ username = "alice"; homeDirectory = "/home/alice"; }
```

The shared `flake.nix` reads it with a fallback:

```nix
local = if builtins.pathExists ./local.nix
        then import ./local.nix
        else { username = "romance"; homeDirectory = "/home/romance"; };
```

Then named configurations (`"wsl"`, `"debian"`) inherit from `local`, while machine-specific
ones (`"osx"`) hardcode their known values. The result: one git repo, one `flake.lock`,
shared modules — only identity is per-machine.

Other common approaches people use:
- **Multiple named outputs**: `homeConfigurations.alice-laptop`, `homeConfigurations.bob-work`.
  Each person or machine gets a named config; you just run `--flake .#your-name`.
- **Specialargs / module options**: pass `username` as `extraSpecialArgs` and reference it
  in modules — modules don't hardcode anything and receive identity as a parameter.
- **Separate repos**: some people fork a shared base and override just the identity parts.

---

### Do `nix *` commands involve only flakes?

No. The `nix` CLI has two modes:

**Flake-aware commands** (new CLI, require a `flake.nix`):
```bash
nix build .#foo
nix develop
nix run github:user/repo#tool
nix flake update
```

**Non-flake commands** (legacy, work with channels / `NIX_PATH`):
```bash
nix-shell -p ripgrep         # uses NIX_PATH/channels
nix-env -iA nixpkgs.ripgrep  # imperative user env
nix-build '<nixpkgs>' -A hello
nix-channel --update
```

The `nix` (new) CLI defaults to flake mode when it finds a `flake.nix`, but you can
point it at channels too with `--file` or `--expr`. The underlying build engine is
identical — the only difference is how inputs are resolved (pinned lock vs ambient channel).

---

### What is the difference between `~/.config` home-manager vs flake-managed?

The location (`~/.config/home-manager/` or `~/git/dots/`) is *independent* of whether
you use flakes. The real distinction is **where the version comes from**:

**Channel-managed** — version comes from `nix-channel`. You `nix-channel --add` a
`home-manager` channel, run `nix-channel --update`, and the version is whatever that
channel currently points at on this machine. Across machines, channels can silently drift.
You run: `home-manager switch` (no `--flake`).

**Flake-managed** (what this repo does) — version is pinned in `flake.lock` to an
exact commit. Every machine with the same `flake.lock` gets byte-identical packages.
Upgrading is explicit: `nix flake update`. You run:
`home-manager switch --flake .#configName`

The `~/.config/home-manager/` path is just the conventional location Home Manager looks
for config when invoked without arguments. You can put a `flake.nix` there and it would
still be flake-managed. This repo keeps it in `~/git/dots/` and always passes
`--flake .` explicitly.

**Summary**: channel-managed = version determined by machine state (mutable, can drift);
flake-managed = version pinned in `flake.lock` (reproducible, explicit to upgrade).
