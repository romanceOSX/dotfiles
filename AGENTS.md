# AGENTS.md

Shared instructions for AI coding agents (Copilot CLI, Codex, Cursor, etc.).
Claude Code reads these via `CLAUDE.md`, which imports this file.

## Compatibility Rules

All the decisions and implementations of this repo should consider the following platforms in mind:
- WSL (on x64 Windows Architecture) 
- MacOS

Everything must be managed through nix (not homebrew, not apt) unless explicitly stated

If there is a package that is not available on both, configuration should handle the platform-specific case

## What this repo is

Personal dotfiles for tmux, zsh, and shell utilities, managed with **Nix /
Home Manager**. A flake (`flake.nix` + `home/*.nix`) reproduces the environment
on macOS, WSL, and Debian. The `home/` modules are the source of truth: they
declare the shell, tools, and configs as native `programs.*` modules. The
`.local/bin/` scripts are installed verbatim into `~/.local/bin`.

See `README.md` for full setup and migration details.

## Source-of-truth rules

- The `home/*.nix` modules are the source of truth. Edit those (or the config
  files they reference under `home/`), not the symlinks in `$HOME`.
- Shell config lives in `home/shell.nix` (zsh: aliases, env, keybindings,
  functions); tmux in `home/tmux.nix`; per-tool configs in `home/programs.nix`.
- On a Home Manager machine the linked files in `$HOME` are **read-only symlinks
  into `/nix/store`** — never edit them in place. Edit the source here, then
  re-activate.

## Making changes

- Edit a `home/*.nix` module or a referenced config file, then run:
  ```sh
  home-manager switch --flake .#<host>   # host: osx | wsl | debian | pi | work
  ```
- Validate Nix changes without applying: `nix flake check`.
- **Commit `flake.lock`** when it changes — it pins exact package versions.
- For tmux-related changes reload tmux's config

## Conventions

- tmux prefix is `C-a`; tmux and shell both use **vi** bindings.
- Shell utilities live in `.local/bin/` (e.g. `tmux-sessionizer`,
  `tmux-launcher`).

## Gotchas

- Home Manager never overwrites files it didn't create; pre-existing files cause
  an "in the way" abort. Use `switch -b backup` to move them aside.
- Keep `local.nix` machine-specific; `local.nix.example` is the template.
