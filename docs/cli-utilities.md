# Modern CLI utilities

The traditional Unix tools are kept; these are the modern replacements installed
on top, wired up in this repo. Packages live in `home/packages.nix` (the
"modern CLI replacements" group), aliases in `home/shell.nix`, and the
`programs.*` integrations as noted.

## What's installed

| Replaces | Tool | Alias / how to use | Notes |
| --- | --- | --- | --- |
| `ls` | **eza** | `ls`, `l` (`-alh`), `ll` (`-lh`), `la` (`-a`) | listing + git status; pastel themed |
| `tree` | **eza** | `tree` → `eza --tree` | |
| `cat` | **bat** | `cat` → `bat --paging=never` | syntax highlight; `programs.bat`, soft theme |
| `find` | **fd** | *(no alias)* use `fd` | different CLI from `find` — not aliased on purpose |
| `grep` | **ripgrep** | *(no alias)* use `rg` | gitignore-aware; not aliased (pipeline-incompatible) |
| `du` | **dust** | `du` → `dust` | disk-usage tree |
| `df` | **duf** | `df` → `duf` | filesystem usage |
| `ps` | **procs** | `ps` → `procs` | |
| `top` | **btop** | `top` → `btop` | pastel-rainbow theme (`~/.config/btop/themes/pastel-rainbow.theme`) |
| `man` | **tealdeer** | *(no alias)* use `tldr` | example docs, not full pages — `man` kept intact |
| `watch` | **viddy** | `watch` → `viddy` | |
| `diff` | **delta** | `diff` → `delta`; also git pager | pastel diff styling |
| `cd` | **zoxide** | `cd` (learns/jumps), `cdi` (picker) | `programs.zoxide --cmd cd` |
| history / fuzzy | **fzf** | `^R` history, `^T` files, `ALT-C` cd | `programs.fzf` |
| `netstat` | **iproute2** (`ss`/`ip`) | use `ss` / `ip` | Linux only — not available on macOS |
| `which` | shell builtin | `which` → `command -v` | |
| `sed` / `awk` | *(kept)* | — | no clear winner; left as-is |

## Deliberately NOT aliased

`find`, `grep`, and `man` are installed (`fd`, `rg`, `tldr`) but **not** aliased:
their CLIs differ enough (incompatible flags, gitignore-by-default, no full man
pages) that aliasing silently breaks scripts and muscle memory. Call them by name.

## Theming (pastel rainbow)

Shared palette, also used by `LS_COLORS`, the btop theme, tmux-nova, and yazi:

```
rose   #C58EA7    purple #CF94F7    blue   #9EC4FE
mint   #94F7E4    peach  #F6CF94    pink   #FA9EC4
green  #B4FA9E
```

- **eza** — `EZA_COLORS` (in `home/shell.nix`) themes permissions, sizes, dates,
  users, and git-status columns; file-type colors come from the shared `LS_COLORS`.
- **delta** — pastel plus/minus/line-number styling in `programs.delta.options`
  (`home/programs.nix`); syntax theme shared with bat.
- **bat** — soft theme via `programs.bat` (`home/programs.nix`).
- **btop** — full custom theme at `~/.config/btop/themes/pastel-rainbow.theme`.
- **procs / dust / duf / viddy** — limited or no theming; left at defaults.

## Updating / removing

These are plain Nix packages: edit `home/packages.nix` (or the relevant
`programs.*` block) and run `home-manager switch --flake .#osx`. See
[nix-concepts.md](nix-concepts.md) for the flake-input vs. switch distinction.
