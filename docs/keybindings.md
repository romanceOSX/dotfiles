# Navigation schema

All interactive menus and pickers in this repo follow the same navigation
contract. New menus should be implemented to match it.

## Universal navigation contract

| Key | Action |
|-----|--------|
| `ctrl+j` / `ctrl+n` | Move down the list |
| `ctrl+k` / `ctrl+p` | Move up the list |
| `ctrl+c` / `esc` | Cancel / dismiss |
| `tab` / `ctrl+y` | Accept (confirm the highlighted entry) |
| `enter` | Submit (confirm and execute) |

Arrow keys always work as a fallback.

## Where it applies

| Menu | Implementation | Config |
|------|---------------|--------|
| `<prefix>f` session-finder | fzf via popup | `~/.config/tmux/sessionizer.toml` |
| `<prefix>w` window picker | fzf via popup | inline in `home/tmux.nix` |
| `<prefix>?` key list | fzf via popup | inline in `home/tmux.nix` |
| Shell history (`^R`) | fzf widget | `programs.fzf` in `home/shell.nix` |
| Tab completion | fzf-tab | `zstyle ':fzf-tab:*'` in `home/shell.nix` |
| `cdi` (zoxide) | fzf widget | `programs.zoxide` in `home/shell.nix` |
| `^T` file picker | fzf widget | `programs.fzf` in `home/shell.nix` |

## Implementation

The contract is enforced via `FZF_DEFAULT_OPTS` (set by `programs.fzf.defaultOptions`
in `home/shell.nix`), which all fzf instances inherit. Menus that run inside
tmux popups as a bare `bash -c` subprocess (where `FZF_DEFAULT_OPTS` is not
inherited from zsh) must pass `--bind` explicitly — see `tmux-sessionizer-menu`.

```
--bind=ctrl-j:down,ctrl-k:up,ctrl-n:down,ctrl-p:up,ctrl-y:accept,tab:accept
```

`tab:accept` removes multi-select toggle. If a future picker needs `-m`,
add a dedicated `FZF_*_OPTS` variable for that invocation.

---

## tmux prefix bindings

Prefix: `C-a`

| Key | Action |
|-----|--------|
| `<prefix> f` | Session-finder (fzf — follows navigation contract) |
| `<prefix> w` | Window picker (fzf — follows navigation contract) |
| `<prefix> ?` | Searchable key list (fzf — follows navigation contract) |
| `<prefix> t` | Session launcher popup |
| `<prefix> T` | taskwarrior-tui popup |
| `<prefix> i` | tmux / continuum info popup |
| `<prefix> r` | Reload tmux config |
| `<prefix> -` | Split pane vertically |
| `<prefix> \|` | Split pane horizontally |
| `<prefix> h/j/k/l` | Navigate panes |
| `<prefix> H/J/K/L` | Resize panes |
| `<prefix> Tab` | Last window |
| `<prefix> n/p` | Next / previous window |
| `<prefix> (/)` | Next / previous session |
| `<prefix> N` | New named session |
| `<prefix> X` | Kill current session |
