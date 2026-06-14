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
- **macOS & bare Linux** run Syncthing via nix (`services.syncthing`). Pair your
  other device + accept the `taskwarrior-sync` folder at <http://127.0.0.1:8384>.
- **WSL** is the exception: Syncthing runs on the *Windows host*, so the nix
  service is disabled there (via the `isWSL` flag in `flake.nix`). Point the sync
  dir at the Windows-synced folder instead, e.g.
  `ln -s /mnt/c/Users/<you>/task-sync ~/.local/share/task-sync`.

## Adding a new machine to the sync (read this when pulling on a new box)

Cloning this repo gives a machine the **tools and settings only** — not your
identity and not your tasks. Each machine generates its own Syncthing identity
(`key.pem`, kept locally, **never committed**); the public **Device IDs** of all
machines are declared in `home/taskwarrior.nix` (`syncthingDevices`). The same
list runs everywhere, so every machine already knows its peers.

To bring a new machine into the mesh:

1. `home-manager switch` on the new machine (installs everything; Syncthing
   generates its identity on first run).
2. Get its Device ID: `syncthing --device-id`.
3. Add it to `syncthingDevices` in `home/taskwarrior.nix`, commit, and **push**.
4. `git pull` + `home-manager switch` on the *other* machines so they learn the
   new peer (the declared list is the source of truth — GUI-added devices are
   reverted on activation).
5. First `task sync` on the new machine pulls your whole task list.

The machine marked `introducer = true` (your always-on host) auto-introduces new
peers to the rest, so in practice you mostly only add the new ID in one place.

**Security:** Device IDs are public (safe in git). The secret is each machine's
Syncthing `key.pem` — `~/Library/Application Support/Syncthing/` on macOS,
`~/.local/state/syncthing/` (or `$XDG_STATE_HOME/syncthing`) on Linux — never
commit it, or a cloner would *become* that device. Same for
`sync.encryption_secret` if you set one (keep it in `local.nix`).

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
