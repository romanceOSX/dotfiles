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

The `client_id` + `encryption_secret` are now stored **encrypted** in
`secrets.yaml` (sops-nix) and decrypted at activation with each host's SSH key
— so they're shared across the mesh by decrypting the same ciphertext, not by
hand-copying values into every `local.nix`. Only the non-secret `serverUrl`
lives in `local.nix`, where it doubles as the per-host "sync on?" gate.

**One-time setup, per machine you want in the sync mesh:**

1. Sign up at <https://app.wingtask.com> and get your sync endpoint
   (`serverUrl`) and `clientId` from the account/sync settings.
2. Generate a shared encryption secret **once**: `openssl rand -base64 32`.
3. Put the two secrets into the encrypted store (only needed the first time, or
   when they change — the ciphertext is committed and shared by all hosts):
   ```sh
   sops secrets.yaml     # edit wingtask_client_id + wingtask_encryption_secret
   ```
   For a **new host** to be able to decrypt, add its age recipient to
   `.sops.yaml` and run `sops updatekeys secrets.yaml`. When the recipient is
   derived from an SSH ed25519 key (the default here), that's:
   ```sh
   ssh-to-age < ~/.ssh/id_ed25519.pub   # → age1... recipient for .sops.yaml
   ```
4. Set the (non-secret) endpoint in that host's `local.nix`:
   ```nix
   wingtaskServerUrl = "https://<your-wingtask-sync-endpoint>";
   ```
5. `home-manager switch --flake .#<host>`, then run `task sync` once (there is
   no separate "init" step — `sync init` is not a real subcommand in TW3's
   native TaskChampion protocol, despite older WingTask docs mentioning it for
   their legacy taskd setup).

Hosts that don't set `wingtaskServerUrl` simply get no sync configured (and no
sops secrets are even requested there) — this is all opt-in per machine.

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

The `client_id` + `encryption_secret` identify and decrypt your task data.
Since the migration to sops-nix they no longer touch plaintext config or the
world-readable Nix store:

1. **`secrets.yaml`** (repo root) — the two values, **encrypted** to the SSH
   ed25519 key(s) listed in `.sops.yaml`. Safe to commit. Edit with
   `sops secrets.yaml`; see `home/secrets.nix` for the wiring.
2. **`~/.config/sops-nix/secrets/rendered/taskrc-sync`** — decrypted at
   activation to a **`0400`** (owner-only) file by the sops-nix launchd/systemd
   agent. `taskrc` pulls it in with an `include`, so the secret never lands in
   the generated, world-readable taskrc or in the Nix store.
3. **`~/.config/task/taskrc`** (`644`) and the store-built `home-manager-taskrc`
   now contain only the `include` line and non-secret settings — no secret.
4. **`local.nix`** holds just the non-secret `wingtaskServerUrl`.

> **Rotate if migrating from the old scheme.** Before this migration the
> secrets lived in `local.nix`; if that file was ever committed, the value is
> in git history and should be rotated. Full step-by-step runbook:
> [`docs/wingtask-key-rotation.md`](./wingtask-key-rotation.md). Note the
> gotcha: WingTask only accepts account-registered `client_id`s, so a new
> secret needs a fresh/empty bucket (reset the client's data, or register a new
> client, in the WingTask UI) before it can seed.

### Caveats

- **`task undo` is effectively disabled.** Syncing discards undo history, and
  we sync after every change.
- **Recurring tasks:** set `recurrence=on` on ONE primary machine and `off` on
  the others to avoid duplicates on sync.
- Hooks live in `<data.location>/hooks` (`~/.local/share/task/hooks`), **not**
  `~/.config/task/hooks` — a TW3 change.
