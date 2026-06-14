# Taskwarrior TODO workflow (experimental)

A terminal-first task manager, fully nix-managed. Config lives in
`home/taskwarrior.nix`. **Status: experimental** — on branch
`feat/taskwarrior-tui-workflow`, tag `exp/taskwarrior-workflow-v0`.

## Stack

| Tool | Role |
| --- | --- |
| **taskwarrior** (v3) | the task manager (SQLite-backed) |
| **taskwarrior-tui** | TUI frontend — the yazi/lazygit of tasks |
| **timewarrior** | time tracking, auto-wired via the `on-modify` hook |
| **taskopen** | open URLs/files annotated on a task |

## Daily use

```bash
ta project:home "buy milk"   # quick add  (alias: task add)
task add project:saas "pricing page"
tn                           # what's next (alias: task next)
task due                     # what's due
task 12 done                 # finish task 12
tt                           # launch the TUI (alias: taskwarrior-tui)
```

In tmux: **`<prefix> T`** opens the TUI in a popup.

### Annotations / taskopen

```bash
task 15 annotate https://github.com/org/repo/issues/42
taskopen 15        # opens the annotated URL/file
```

### Time tracking

`task <id> start` / `stop` automatically logs a Timewarrior interval (via the
`on-modify` hook). Report with:

```bash
timew summary :week
```

## Sync (serverless — Option A)

No external service, no cloud. Uses **TaskChampion local sync**: `task sync`
reconciles your local DB against an on-disk op-log at `~/.local/share/task-sync`,
and **Syncthing replicates that dir** (not the live DB) across machines.

- **Automatic:** an `on-exit` hook runs `task sync` after every change, so you
  normally never sync by hand. `tsync` (= `task sync`) is there if you want to.
- macOS runs Syncthing via nix (`services.syncthing`). Pair your other device +
  accept the `taskwarrior-sync` folder at <http://127.0.0.1:8384>.
- **WSL:** Syncthing runs on the *Windows host*; point the sync dir at the
  Windows-synced folder, e.g.
  `ln -s /mnt/c/Users/<you>/task-sync ~/.local/share/task-sync`.

### Caveats

- **`task undo` is effectively disabled.** Syncing discards undo history, and we
  sync after every change. (Switch to debounced/periodic sync if you want undo.)
- **Recurring tasks:** set `recurrence=on` on ONE primary machine and `off` on
  the others to avoid duplicates on sync.
- **At-rest encryption (optional):** set the *same* `sync.encryption_secret` on
  every machine (keep it out of git — e.g. in `local.nix`) to encrypt the synced
  op-log.
- Hooks live in `<data.location>/hooks` (`~/.local/share/task/hooks`), **not**
  `~/.config/task/hooks` — a TW3 change.
