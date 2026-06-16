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

- `flake.nix` — entry point; defines `romance@mac`, `romance@wsl`, `romance@debian`
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
nix run home-manager/master -- switch --flake .#romance@wsl       # or romance@debian / romance@mac

# subsequent updates
home-manager switch --flake ~/git/dotfiles#romance@wsl
```

> Edit the `username` / `homeDirectory` in `flake.nix` if your login differs.
> Validate without activating: `nix flake check`.

### migrating a machine that already has dotfiles

Home Manager **never overwrites files it didn't create**. If `~/.zshrc`,
`~/.config/...`, etc. already exist, `switch` *aborts* with an "in the way"
error instead of clobbering them. Let HM move the conflicts aside as it links:

```sh
home-manager switch -b backup --flake .#romance@<host>
```

`-b backup` renames each existing file to `<name>.backup` before linking, so
nothing is lost — diff or delete the `.backup` files afterwards.

**Packages** (Homebrew / apt) are left untouched — HM installs its own into the
Nix profile; both can coexist on `PATH`. Remove the old ones later if you want.

### making changes (you don't edit the linked files directly)

Once a machine is on Home Manager, the dotfiles in `$HOME` are **read-only
symlinks into `/nix/store`** — you can't edit them in place. The workflow is
always: edit the *source* in this repo, then re-activate.

```sh
# 1. edit either:
#      - a .nix module under home/      (e.g. add a package to home/packages.nix)
#      - or a referenced config file    (home/yazi/theme.toml, home/starship.toml, …)
# 2. apply it:
home-manager switch --flake .#romance@<host>
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
> and names the host configs; the `home/*.nix` files *declare what you want*
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

To customize, copy the example and edit the copy:

```sh
cp ~/.config/tmux/sessionizer.toml.example ~/.config/tmux/sessionizer.toml
$EDITOR ~/.config/tmux/sessionizer.toml
```

The menu reads the file fresh on every `<prefix>f` keypress, so edits to your
override are **live — no `home-manager switch`, no tmux reload**. (Changing the
shipped default in `home/tmux-sessionizer.toml.example` still needs a `switch`.)
