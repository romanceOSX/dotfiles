# dots

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
git clone <repo> ~/git/dots && cd ~/git/dots

# 3. activate (pick the host matching the machine; adjust username in flake.nix)
nix run home-manager/master -- switch --flake .#wsl       # or debian / osx

# subsequent updates
home-manager switch --flake ~/git/dots#wsl
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

---

## What's installed

A quick reference for everything declared across the `home/*.nix` modules, grouped by purpose.

### AI & agents

| Tool | Alias | What it does |
|---|---|---|
| **aoe** (agent-of-empires) | `aoe` | TUI for running multiple AI coding agents in parallel across git branches. Custom pastel-rainbow theme shipped in this repo. |
| **tokscale** | `toks` | Tracks token usage across agentic coding tools (Claude Code, OpenCode, etc.). Supports monthly/hourly reports, a TUI, and a social submission mode. |
| **openai-whisper** | `whisper` | Local speech-to-text transcription. |
| **copilot-sessions** | `.local/bin` | Shell helper for managing GitHub Copilot CLI sessions. |

### Editor

**Neovim** (pinned to 0.12.0 via a separate nixpkgs input — see `flake.nix`). The binary comes from Nix; the config does **not** — `~/.config/nvim` is a live symlink to `~/git/init.lua`, so edits there take effect immediately with no rebuild. Aliases: `vim`, `vi`.

LSP servers installed alongside it:

| Server | Language |
|---|---|
| `lua-language-server` | Lua |
| `pyright` | Python |
| `bash-language-server` | Bash / Zsh |
| `marksman` | Markdown |
| `clangd` (via `clang-tools`) | C / C++ (forced to C++23 via `~/.config/clangd/config.yaml`) |
| `rust-analyzer` | Rust |

Formatters: `stylua`, `black`, `isort`, `prettier`, `mdformat`.

### Shell & prompt

| Tool | Notes |
|---|---|
| **zsh** | vi-mode, fzf-tab completion, 100k history, emacs-in-insert keybindings (`^A/^E/^R`…) |
| **starship** | Prompt — config at `home/starship.toml` |
| **fzf** | Fuzzy finder — `^R` history, `^T` file, `ALT-C` dir; unified nav keys across all pickers |
| **fzf-tab** | Replaces zsh's Tab completion menu with fzf |
| **zoxide** | Smart `cd` that learns jump targets; `--cmd cd` shadows the builtin; `cdi` for interactive picker |

### Git

| Tool | Alias | Notes |
|---|---|---|
| **lazygit** | `lg` | TUI for git — pastel-rainbow theme |
| **delta** | `diff` | Syntax-highlighted diffs and git pager; Coldark-Dark syntax theme |
| **gh** (GitHub CLI) | `gh` | Auth + API; `gh co` = `gh pr checkout` |
| **gh-dash** | `gh dash` | TUI dashboard for PRs and issues across repos |
| **gh-notify** | `gh notify` | fzf TUI for GitHub notifications |

### File manager

**yazi** — terminal file manager with previews. Launched via the `y` wrapper (returns to the last directory on exit). Preview dependencies installed alongside it: `ffmpeg`, `jq`, `poppler-utils`, `_7zz`, `resvg`, `imagemagick`, `chafa`.

### Modern CLI replacements

| Alias | Tool | Replaces |
|---|---|---|
| `ls`, `l`, `ll`, `la`, `tree` | **eza** | `ls` — icons, git status, pastel-rainbow theme |
| `cat` | **bat** | `cat` — syntax highlighting, Coldark-Dark theme |
| `du` | **dust** | `du` — disk-usage tree |
| (interactive) | **dua** | `du` — interactive disk-usage analyzer |
| `df` | **duf** | `df` — filesystem usage |
| `ps` | **procs** | `ps` — process listing |
| `watch` | **viddy** | `watch` — live command output |
| `diff` | **delta** | `diff` — syntax-highlighted diffs |
| `cd` | **zoxide** | `cd` — smart jump (learns from usage) |
| — | **fd** | `find` (not aliased — different CLI) |
| — | **ripgrep** (`rg`) | `grep` (not aliased — different CLI) |
| — | **tealdeer** (`tldr`) | `man` (not aliased — different CLI) |

### System monitoring

| Tool | Notes |
|---|---|
| **btop** | `top` replacement — custom pastel-rainbow theme, proc tree, per-core CPU |
| **fastfetch** | System info banner |
| **macchina** | Lightweight system info |
| **hyfetch** | Pride-flag system info banner |
| **colima** | Docker/container runtime for macOS (lightweight alternative to Docker Desktop) |

### Networking

| Tool | Notes |
|---|---|
| **tailscale** | Mesh VPN — remote access between machines (node `love` at `100.73.134.15`) |
| **nmap** | Port scanner |
| **curl** | HTTP client |
| **dig** | DNS lookups |
| **mtr** | Traceroute + ping combined |

### Toolchains

- **Node.js 22** (`node`, `npm`, `npx`) — replaces the old Homebrew nvm lazy-load
- **Rust** (`rustc`, `cargo`, `rustfmt`, `clippy`, `rust-analyzer`)
- **Clang / C++** (`clang`, `clang++` with `-std=c++20` alias, `clangd`, `cmake`)
- **Python 3** (`python`, `pip` aliases); **uv** for fast package/project management
- **tree-sitter CLI** — used by nvim-treesitter to compile parsers

### Clipboard

| Script | Notes |
|---|---|
| **clipd** | Daemon that polls `pbpaste` (macOS) or Wayland clipboard and stores history under `~/.local/share/cliph/`. Runs as a launchd agent on macOS; auto-started from zshrc on Linux/Wayland. |
| **cliph** | fzf picker over clipboard history — bound to `^Y` in zsh insert-mode and `prefix+y` in tmux. |

### Shell scripts (`.local/bin`)

| Script | Notes |
|---|---|
| `tmux-sessionizer` | `prefix+f` — fzf menu to create/switch tmux sessions by project dir (config: `~/.config/tmux/sessionizer.toml`) |
| `tmux-launcher` | `prefix+g` — quick-launch menu for common commands in new windows/panes |
| `tmux-sessionizer-menu` | `display-menu` variant of the sessionizer |
| `tmux-rainbow` | Renders the sine-wave pastel-rainbow gradient in the tmux status bar |
| `tmux-agent-monitor` | Monitors AI agent panes and alerts on completion/errors |
| `tmux-ssh-menu` | `prefix+s` — fzf menu for SSH connections |
| `tmux-remote-shell` | Opens a remote shell in a new tmux split via SSH |
| `tmux-resurrect-prune` | Prunes old tmux-resurrect save files |
| `tmux-continuum-ensure-hook` | Ensures continuum save hooks are registered |
| `tmux-conf-info` | Prints a summary of active tmux configuration |
| `rainbow-prompt` | Generates the starship custom module gradient (called by `starship.toml`) |
| `taskfzf` | fzf interface for Taskwarrior tasks |
| `clipd` / `cliph` | Clipboard history daemon + picker (see Clipboard above) |
| `copilot-sessions` | GitHub Copilot CLI session manager |
| `install-tailscaled-daemon` | One-shot script to install the tailscale daemon service |
| `wsl-sync-dns` | Syncs WSL `/etc/resolv.conf` with the Windows DNS config |
| `fix-sudo-path` | (Linux) Adds Nix bin paths to `sudo`'s `secure_path` (via an `/etc/sudoers.d/nix-path` drop-in) so Nix-installed tools work under sudo |
| `enable-wake-on-lan` | Enables Wake-on-LAN on the active network interface |
| `rom-claude-mem` | Standalone `/memory` picker for Claude Code — edit user/project `CLAUDE.md` or open the auto-memory folder outside the REPL |
| `install-sshd-daemon` | (Linux) Sets up the openssh daemon as a user service |
