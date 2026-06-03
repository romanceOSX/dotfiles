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
