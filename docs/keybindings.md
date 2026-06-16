# Navigation schema

Two types of interactive menus exist in this repo; each has its own contract.

---

## fzf pickers

Applies to all fzf-based pickers: shell history, tab completion, zoxide `cdi`,
and tmux popup pickers (`<prefix>w`, `<prefix>?`).
Enforced via `FZF_DEFAULT_OPTS` in `home/shell.nix`; fzf-tab gets the same
flags via `zstyle ':fzf-tab:*' fzf-flags`.

| Key | Action |
|-----|--------|
| `ctrl+j` / `ctrl+n` | Move down |
| `ctrl+k` / `ctrl+p` | Move up |
| `ctrl+c` / `esc` | Cancel |
| `tab` / `ctrl+y` | Accept |
| `enter` | Submit |

Arrow keys always work as a fallback.

**Implementation note:** fzf instances running inside a bare `bash -c` tmux
popup don't inherit `FZF_DEFAULT_OPTS` from zsh — pass `--bind` explicitly:
```
--bind=ctrl-j:down,ctrl-k:up,ctrl-n:down,ctrl-p:up,ctrl-y:accept,tab:accept
```

`tab:accept` removes multi-select toggle. Add a dedicated `FZF_*_OPTS` if a
future picker needs `-m`.

---

## tmux display-menus

Applies to native tmux menus: `<prefix>f` session-finder.
`display-menu` navigation is fixed by tmux and cannot be rebound.

| Key | Action |
|-----|--------|
| `↑` / `↓` (or `k` / `j`) | Move up / down |
| `esc` / `q` | Cancel |
| `enter` | Select highlighted entry |
| Letter shortcut | Jump directly to that entry |

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
