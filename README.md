# dotfiles

Config for tmux, zsh, and shell utilities, managed with Nix / Home Manager.

### requirements

- [Nix](https://nixos.org) with flakes (the Determinate installer enables them) —
  see bootstrap below.

### structure

- `home/` — Home Manager modules; the source of truth for the whole environment
- `home/shell.nix` — zsh entry point: env, aliases, vi-mode, functions
- `home/tmux.nix` — tmux config, `C-a` prefix, vi bindings
- `.local/bin/` — shell utilities (`tmux-sessionizer`, `tmux-launcher`)

---

## Nix / Home Manager (reproducible env)

A [Home Manager](https://nix-community.github.io/home-manager/) flake reproduces
this whole environment (zsh, starship, fzf, lazygit, yazi, tmux, neovim, plus
Node/Rust/C++ toolchains) on macOS, WSL, and Debian — no NixOS required. The
`home/*.nix` modules are the source of truth; they declare the shell/tool
configs as native `programs.*` modules.

### layout

- `flake.nix` — entry point; defines hosts `osx`, `wsl`, `debian`, `pi`, `work`
- `home/` — the Home Manager modules
  - `default.nix` — imports + stateVersion
  - `packages.nix` — toolchains (Node/Rust/clang) + CLI utilities
  - `shell.nix` — zsh, fzf, starship, env, aliases, vi-mode
  - `programs.nix` — lazygit, yazi, neovim, git
  - `tmux.nix` — tmux + nix-managed plugins
  - `scripts.nix` — `.local/bin/*` → `~/.local/bin`

### bootstrap on a new machine (WSL / Debian)

```sh
# 1. install Nix (Determinate installer enables flakes for you)
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

# 2. get the repo
git clone <repo> ~/git/dotfiles && cd ~/git/dotfiles

# 3. activate (pick the host matching the machine; adjust username in flake.nix)
nix run home-manager/master -- switch --flake .#wsl       # or debian / osx

# subsequent updates
home-manager switch --flake ~/git/dotfiles#wsl
```

> Edit the `username` / `homeDirectory` in `flake.nix` if your login differs.
> Validate without activating: `nix flake check`.

### machine-local config from templates (`copy-examples.sh`)

A few configs are deliberately **not** managed by Nix — each host edits its own
copy (e.g. `local.nix`, `~/.config/tmux/sessionizer.toml`). Their tracked
`*.example` templates are materialized at the right path by one convenience
script:

```sh
./copy-examples.sh           # create any missing config from its template
./copy-examples.sh --force   # overwrite existing configs from the templates
```

It skips files that already exist (so it's safe to re-run), creates parent
directories, and warns if a tracked `*.example` has no destination mapped yet —
add new templates to the `MAP` table near the top of the script.

### migrating a machine that already has dotfiles

Home Manager **never overwrites files it didn't create**. If `~/.zshrc`,
`~/.config/...`, etc. already exist, `switch` _aborts_ with an "in the way"
error instead of clobbering them. Let HM move the conflicts aside as it links:

```sh
home-manager switch -b backup --flake .#<host>
```

`-b backup` renames each existing file to `<name>.backup` before linking, so
nothing is lost — diff or delete the `.backup` files afterwards.

**Packages** (Homebrew / apt) are left untouched — HM installs its own into the
Nix profile; both can coexist on `PATH`. Remove the old ones later if you want.

### making changes (you don't edit the linked files directly)

Once a machine is on Home Manager, the dotfiles in `$HOME` are **read-only
symlinks into `/nix/store`** — you can't edit them in place. The workflow is
always: edit the _source_ in this repo, then re-activate.

```sh
# 1. edit either:
#      - a .nix module under home/      (e.g. add a package to home/packages.nix)
#      - or a referenced config file    (home/yazi/theme.toml, home/starship.toml, …)
# 2. apply it:
home-manager switch --flake .#<host>     # host: osx | wsl | debian | pi | work
```

Useful commands:

```sh
nix flake check            # validate the config without applying it
nix flake update           # bump nixpkgs / home-manager, rewrites flake.lock
home-manager generations   # list past builds; roll back by running an older one's activate script
```

> **Commit `flake.lock`** after the first `switch`. It pins exact package
> versions so every machine builds an identical environment; without it, each
> machine resolves `nixpkgs` to whatever is current that day.

> **Mental model (for the Nix-unfamiliar):** `flake.nix` lists the pinned inputs
> and names the host configs; the `home/*.nix` files _declare what you want_
> (packages, programs, settings); `switch` makes your `$HOME` match that
> declaration. You describe the end state — Nix works out the steps. Editing a
> `.nix` file changes nothing until you run `switch` again.

### tmux session-finder config (default + override)

`<prefix>f` opens a session-finder menu whose entries (key → directories) come
from a TOML config. It uses a **default + optional override** model:

- **Default** — `~/.config/tmux/sessionizer.toml.example` is shipped by Home
  Manager (read-only, from `home/tmux-sessionizer.toml.example`). The menu falls
  back to it when no override exists, so `<prefix>f` works out of the box.
- **Override** — `~/.config/tmux/sessionizer.toml`, if present, takes
  precedence. It is **not** Nix-managed (machine-local, like `local.nix`), so
  it's yours to create and edit freely.

To customize, create the override and edit it. Either run the convenience
script (see below) or copy the example by hand:

```sh
./copy-examples.sh                                   # creates it if missing
# …or manually:
cp ~/.config/tmux/sessionizer.toml.example ~/.config/tmux/sessionizer.toml
$EDITOR ~/.config/tmux/sessionizer.toml
```

The menu reads the file fresh on every `<prefix>f` keypress, so edits to your
override are **live — no `home-manager switch`, no tmux reload**. (Changing the
shipped default in `home/tmux-sessionizer.toml.example` still needs a `switch`.)

### git identity (machine-local, not Nix-managed)

Home Manager owns `~/.config/git/config` (read-only symlink into the store), but
your `user.name` / `user.email` are **deliberately not declared in Nix**. The
managed config ends with `[include] path = ~/.config/git/config.local`, and that
local file is yours to create and edit freely — no `local.nix`, no
`home-manager switch`. Git silently ignores it when absent, so a fresh machine
still works.

Set or change your identity any time with:

```sh
git config -f ~/.config/git/config.local user.name  "Your Name"
git config -f ~/.config/git/config.local user.email "you@example.com"
```

Verify where it resolves from with `git config --show-origin --get user.email`.
