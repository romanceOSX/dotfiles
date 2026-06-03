# dotfiles

Config for tmux, zsh, and shell utilities.

### requirements

- [GNU Stow](https://www.gnu.org/software/stow/) — `brew install stow`
- [Starship](https://starship.rs) — `brew install starship`

### install

```sh
git clone <repo> ~/git/dotfiles
cd ~/git/dotfiles
./install.sh
```

### structure

- `.zshrc` — zsh entry point, sources `.commonrc`
- `.commonrc` — shared shell config (bash & zsh compatible)
- `.tmux.conf` — tmux config, `C-a` prefix, vi bindings
- `.local/bin/` — shell utilities (`tmux-sessionizer`, `tmux-launcher`)

---

## Nix / Home Manager (reproducible env)

A [Home Manager](https://nix-community.github.io/home-manager/) flake reproduces
this whole environment (zsh, starship, fzf, lazygit, yazi, tmux, neovim, plus
Node/Rust/C++ toolchains) on macOS, WSL, and Debian — no NixOS required. The
shell/tool configs are translated into native `programs.*` modules under
`home/`; the hand-written dotfiles above stay as the source of truth for the
stow path.

### layout

- `flake.nix` — entry point; defines `romance@mac`, `romance@wsl`, `romance@debian`
- `home/` — the Home Manager modules
  - `default.nix` — imports + stateVersion
  - `packages.nix` — toolchains (Node/Rust/clang) + CLI utilities
  - `shell.nix` — zsh, fzf, starship, env, aliases, vi-mode (from `.commonrc`/`.zshrc`)
  - `programs.nix` — lazygit, yazi, neovim, git
  - `tmux.nix` — tmux + nix-managed plugins (from `.tmux.conf`)
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
error instead of clobbering them. Clear the path first, depending on how that
machine is currently managed:

**Already using this repo via stow** — remove the stow symlinks, then activate:

```sh
cd ~/git/dotfiles && stow -D .                 # unlink the stow-managed files
home-manager switch --flake .#romance@<host>
```

Don't run stow *and* Home Manager on the same machine — they manage the same
paths and will fight. Unstowing is the handoff.

**Plain / hand-edited dotfiles** — let HM move the conflicts aside as it links:

```sh
home-manager switch -b backup --flake .#romance@<host>
```

`-b backup` renames each existing file to `<name>.backup` before linking, so
nothing is lost — diff or delete the `.backup` files afterwards.

**Packages** (Homebrew / apt) are left untouched — HM installs its own into the
Nix profile; both can coexist on `PATH`. Remove the old ones later if you want.

### making changes (you don't edit the linked files directly)

Once a machine is on Home Manager, the dotfiles in `$HOME` are **read-only
symlinks into `/nix/store`** — you can't edit them in place like the stow setup.
The workflow is always: edit the *source* in this repo, then re-activate.

```sh
# 1. edit either:
#      - a .nix module under home/      (e.g. add a package to home/packages.nix)
#      - or a referenced config file    (.config/yazi/theme.toml, .config/starship.toml, …)
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
