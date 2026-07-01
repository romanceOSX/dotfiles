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

## Sync (cloud — WingTask)

Tasks sync via [WingTask](https://wingtask.com), a hosted **TaskChampion** sync
server with a web/PWA client — so the same tasks are reachable from a phone or
browser, not just machines that clone this repo. (Previously used a serverless
Syncthing-replicated local sync dir with no external service — see git history
at commit `01edd671` if you want to revert to that instead.)

**One-time setup, per machine you want in the sync mesh:**

1. Sign up at <https://app.wingtask.com> and get your sync endpoint
   (`serverUrl`) and `clientId` from the account/sync settings.
2. Generate a shared encryption secret **once**: `openssl rand -base64 32`.
3. Add all three to `local.nix` on that machine (kept out of git deliberately —
   never commit real credentials):
   ```nix
   wingtaskServerUrl = "https://<your-wingtask-sync-endpoint>";
   wingtaskClientId = "<uuid-from-wingtask>";
   wingtaskEncryptionSecret = "<the-secret-from-step-2>";
   ```
   `clientId` and `encryptionSecret` **must be identical** on every machine
   sharing this task database — `clientId` identifies the shared task database
   itself, not the individual machine.
4. `home-manager switch --flake .#<host>`, then run `task sync` once (there is
   no separate "init" step — `sync init` is not a real subcommand in TW3's
   native TaskChampion protocol, despite older WingTask docs mentioning it for
   their legacy taskd setup).

Hosts that don't set these three fields simply get no sync configured — this
is all opt-in per machine.

**If this machine already has real task history** (e.g. it was previously in
the Syncthing/local-sync mesh — this applies to `osx`, which was), the first
`task sync` will likely fail with something like:

```
Failed to synchronize with server: Server Error: https://sync.wingtask.com/v1/client/get-child-version/<uuid> responded with 410 Gone
```

This is **not a credentials or config problem** — a brand-new/empty replica
syncs against the same server/client_id/secret without issue. The cause is
that `~/.local/share/task/taskchampion.sqlite3` carries internal sync
bookkeeping from the old local-sync setup, which conflicts with a fresh,
never-before-synced WingTask account. Fix it once, per machine, like this
(your tasks are never lost — only the sync bookkeeping is reset):

```bash
# 1. Back up (belt and suspenders — this dir is small)
cp -a ~/.local/share/task ~/.local/share/task-backup-$(date +%Y%m%d-%H%M%S)

# 2. Export everything (all statuses)
task export > /tmp/task-export.json

# 3. Move the old db aside so Taskwarrior creates a fresh, empty replica
mv ~/.local/share/task/taskchampion.sqlite3 ~/.local/share/task/taskchampion.sqlite3.pre-wingtask-migration

# 4. Confirm the fresh replica syncs cleanly (this also pulls down WingTask's
#    default onboarding tasks — harmless, delete them once read)
task sync

# 5. Reimport your tasks and push them up
task import /tmp/task-export.json
task sync
```

Sanity-check before/after with `task export | python3 -c "import json,sys;
print(len(json.load(sys.stdin)))"` to confirm the count you expect is present,
then delete the `.pre-wingtask-migration` file and the backup dir once happy.

**Automatic sync is two-sided:**

- **Push:** an `on-exit` hook runs `task sync` after every local change, so
  edits made here reach WingTask within moments.
- **Pull:** nothing local triggers a pull when a task is added/edited from the
  WingTask web UI or phone PWA, so a timer runs `task sync` every 10 minutes
  (`systemd --user` timer on Linux, a `launchd` agent on macOS) to catch those
  changes. `tsync` (= `task sync`) is there for an immediate manual sync.
- **WSL:** the systemd timer needs `systemd=true` in `/etc/wsl.conf`. If that's
  not set, fall back to manual `tsync` (or a Windows Task Scheduler entry
  running `wsl.exe -e task sync`).

### Where the credentials end up

`wingtaskClientId` and `wingtaskEncryptionSecret` identify and decrypt your
task data, so it's worth knowing exactly where they land on a given machine:

1. **`local.nix`** (repo root) — plaintext. Deliberately *not* gitignored (so
   the flake can read it) but meant to stay uncommitted: `git add local.nix`
   is required for the flake to see it (untracked files are invisible to a
   git-based flake), but **never `git commit` it**.
2. **`~/.config/task/taskrc`** — the rendered config, `644` (world-readable on
   that machine). Home Manager regenerates this as a real file (not a store
   symlink) via the `regenDotTaskRc` activation step, since `task config`
   needs to write to it directly.
3. **The Nix store** — the built `hm_...taskrc` derivation is `444 root:root`,
   which is **world-readable by Nix design** (any local user on the machine
   can read store paths) and **persists even after you delete/change
   `local.nix`**, until garbage collected (`nix-collect-garbage`). This is a
   general property of secrets passed through `home.file`/`programs.*.config`
   in Nix, not specific to this setup — if that's ever a real concern (e.g. a
   genuinely multi-user machine), look at `sops-nix` or `agenix` instead of
   plain `local.nix`.

### Caveats

- **`task undo` is effectively disabled.** Syncing discards undo history, and
  we sync after every change.
- **Recurring tasks:** set `recurrence=on` on ONE primary machine and `off` on
  the others to avoid duplicates on sync.
- Hooks live in `<data.location>/hooks` (`~/.local/share/task/hooks`), **not**
  `~/.config/task/hooks` — a TW3 change.
