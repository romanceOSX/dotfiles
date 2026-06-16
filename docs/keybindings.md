# Keybindings

## fzf (all pickers)

Applies everywhere fzf is used: shell history (`^R`), tab completion
(`fzf-tab`), zoxide's `cdi`, and all tmux popup pickers.
Configured via `FZF_DEFAULT_OPTS` in `home/shell.nix`.

### Navigation (selecting from the entry list)

| Key | Action |
|-----|--------|
| `ctrl+j` / `ctrl+k` | Move down / up |
| `ctrl+n` / `ctrl+p` | Move down / up (alternate) |
| `ctrl+c` / `esc` | Cancel / dismiss |
| `tab` / `ctrl+y` | Accept selection (confirm without submitting) |
| `enter` | Submit selection |

### Notes

- `tab` is rebound from multi-select toggle to accept — if a future picker
  needs multi-select (`fzf -m`), add a dedicated `FZF_*_OPTS` override for it.
- fzf-tab receives the same bindings via `zstyle ':fzf-tab:*' fzf-flags`.

---

## tmux

Prefix: `C-a`

| Key | Action |
|-----|--------|
| `<prefix> f` | Session-finder menu (reads `~/.config/tmux/sessionizer.toml`) |
| `<prefix> w` | Window picker (fzf) |
| `<prefix> ?` | Searchable key list (fzf) |
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
