# Navigation schema

This repo defines **one** common navigation schema. It concerns how the user
interacts with any menu — the shortcuts, not the underlying widget. Every menu
in the dotfiles (fzf pickers, custom scripts, tmux popups) should follow it so
the interaction is identical everywhere.

There are two menu *categories* by implementation (fzf-based pickers and tmux
native menus), but they share this single interaction schema.

## The schema

| Key                                  | Action    |
| ------------------------------------ | --------- |
| `ctrl+j` / `ctrl+n` / down arrow key | Move down |
| `ctrl+k` / `ctrl+p` / up arrow key   | Move up   |
| `ctrl+c` / `esc`                     | Cancel    |
| `tab` / `ctrl+y`                     | Accept    |
| `enter`                              | Submit    |

**Avoid raw letters.** Standalone letter keys (i.e. without `ctrl`) should not
be used as menu controls — every binding above is either a `ctrl`-chord, a
named key, or an arrow.

## How it is enforced

- **Shell fzf pickers** (history `^R`, `^T`, zoxide `cdi`): inherit the schema
  via `FZF_DEFAULT_OPTS`, set by `programs.fzf.defaultOptions` in
  `home/shell.nix`.
- **Tab completion** (`fzf-tab`): gets the same binds via
  `zstyle ':fzf-tab:*' fzf-flags` in `home/shell.nix`.
- **tmux popup pickers** (`<prefix>w`, `<prefix>?`) and **script pickers**
  (`tmux-sessionizer`, `tmux-launcher`): a tmux popup runs fzf via `sh -c`,
  which does not reliably inherit `FZF_DEFAULT_OPTS` from the (possibly frozen)
  tmux server environment — so each passes the binds inline. The canonical
  string, kept identical across all of them, is:

  ```
  --bind=ctrl-j:down,ctrl-k:up,ctrl-n:down,ctrl-p:up,ctrl-y:accept,tab:accept
  ```

  In `home/tmux.nix` it lives in the `fzfNav` let-binding; the scripts define
  it as `FZF_NAV`.

`ctrl+c`/`esc` (cancel) and `enter` (submit) are fzf defaults, so they need no
explicit binding. `tab:accept` removes fzf's multi-select toggle — fine for all
current pickers; a future `-m` picker would need its own override.

## New menus

Any new menu must follow the schema. If it is fzf-based, reuse the bind string
above (inline for popups/scripts; otherwise it is inherited). Do not introduce
raw-letter controls.

## Known exception: tmux `display-menu`

`<prefix>f` (the session-finder) uses tmux's native `display-menu`. tmux 3.6
has **no configurable key table for menus** — navigation (arrows, `enter`,
`esc`) and the per-entry letter mnemonics are hardcoded by tmux and cannot be
rebound. It therefore cannot honor the full schema (no `ctrl+j/k`, no
`tab`/`ctrl+y` accept) and inherently uses raw-letter shortcuts for its
entries. This is a tmux limitation, not a choice; it is the only menu in the
repo exempt from the schema. The arrow keys, `esc`, and `enter` it does support
still match the schema.

## Remote (SSH) sessions

`<prefix>f s` opens the SSH connections menu (`tmux-ssh-menu`): a fzf list of
configured (`[[ssh]]` in `sessionizer.toml`) and currently-connected hosts with
their live status and session count, plus a "new connection" entry that accepts
any hostname/IP. Selecting a host re-enters the sessionizer's directory picker
**over the remote filesystem**, then opens a local tmux session whose `editor`
(remote nvim) and `shell` panes ssh into the host at the chosen dir.

Remote sessions are **visually distinct**: the status bar is tinted muted amber
(`#F6CF94`) instead of the local mauve, and the session is named `<host>·<dir>`
so the host shows in the status-bar segment. Connections are multiplexed
(`ControlMaster`) over the existing ssh transport — no extra ports, works over
Tailscale and locked-down networks.

---

## tmux prefix bindings

Prefix: `C-a`

| Key | Action |
|-----|--------|
| `<prefix> f` | Session-finder (display-menu — see exception above) |
| `<prefix> f a` | Agent monitor — claude/copilot sessions (fzf) |
| `<prefix> f s` | SSH connections menu (fzf) — open/resume a remote session |
| `<prefix> w` | Window picker (fzf — follows schema) |
| `<prefix> ?` | Searchable key list (fzf — follows schema) |
| `<prefix> t` | Command launcher popup (fzf — follows schema) |
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
