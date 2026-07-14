# WingTask key rotation runbook

Rotating the WingTask **`encryption_secret`** (the shared, client-side key that
encrypts your Taskwarrior data) across the whole sync mesh. Secrets live
encrypted in `secrets.yaml` (sops-nix) and are decrypted per host with its SSH
ed25519 key. See also `docs/taskwarrior.md` and `home/secrets.nix`.

> **Key fact that shapes everything below:** the `encryption_secret` is
> client-side — WingTask never sees it, it only stores opaque blobs. So you
> don't "update" it on the server; you re-encrypt the data by seeding a
> **fresh/empty bucket**. And WingTask only accepts `client_id`s **registered
> in your account** — a random UUID gets `404` on write. So a secret rotation
> needs one server-side action: either reset the current client's data, or
> register a new client, in the WingTask web UI.

Mesh hosts (each an age recipient in `.sops.yaml`): **osx, alien, pi,
remote-left**.

---

## 1. Pre-rotation checklist

- **Back up tasks on the source-of-truth machine** (they're never lost, but):
  ```sh
  cp -a ~/.local/share/task ~/.local/share/task-backup-$(date +%Y%m%d-%H%M%S)
  task export > /tmp/task-export.json
  task count            # note the number; sanity-check it after
  ```
- **Confirm every mesh host can decrypt** (its recipient is in `.sops.yaml`):
  ```sh
  grep -A6 creation_rules .sops.yaml
  ```
- **Plan a quiet window.** During rotation, a host on the new secret and one on
  the old secret cannot sync with each other — do all hosts in one pass.
- **Decide the server-side move** (needed because the secret is client-side):
  - **A — reset current client's data** in the WingTask UI (keeps the same
    `client_id`), or
  - **B — register a new client** in the WingTask UI and copy its `client_id`.

## 2. Generation

New encryption secret (hex — no shell/`taskrc`-hostile characters):
```sh
openssl rand -hex 32
```
If you chose **B**, also grab the new `client_id` from the WingTask dashboard
(don't invent one — unregistered ids 404).

## 3. Implementation

All in `~/git/dots`. Edit the encrypted store (sops opens `$EDITOR`):
```sh
sops secrets.yaml
#   wingtask_encryption_secret: <new hex secret>
#   wingtask_client_id: <new id if you chose B; unchanged for A>
```
Do the WingTask-side action now (reset data for the client, or confirm the new
client exists) so the bucket is empty for the new secret.

Roll it out to every host — commit first so remotes can pull:
```sh
git add secrets.yaml && git commit -m "rotate WingTask encryption_secret"
git push origin master

home-manager switch --flake .#osx          # this machine
nix-deploy alien pi                         # tailscale nodes
# remote-left (its own local.nix identity — don't clobber it; hm-switch
# auto-swaps the unreachable work-dotfiles input for nix/wd-stub):
ssh axxis-remote-left 'cd ~/git/dots && cp local.nix /tmp/keep && \
  git fetch origin && rm -f local.nix && git reset --hard origin/master && \
  cp /tmp/keep local.nix && hm-switch wsl -b backup'
```

Seed the fresh bucket **from one machine** (the one with authoritative tasks):
```sh
mv ~/.local/share/task/taskchampion.sqlite3 ~/.local/share/task/taskchampion.sqlite3.pre-rotation
task sync                                   # establishes the empty bucket
task import /tmp/task-export.json
task sync                                   # pushes your tasks, new-secret-encrypted
```
Then on **every other** host, reset its replica so it re-pulls cleanly:
```sh
ssh <host> 'mv ~/.local/share/task/taskchampion.sqlite3{,.pre-rotation}; task sync'
```

## 4. Verification

Per host (source nix first on remotes: `. ~/.nix-profile/etc/profile.d/*.sh`):
```sh
# secret rendered 0400, no secret leaked into the world-readable taskrc:
ls -l ~/.config/sops-nix/secrets/rendered/taskrc-sync
grep -c encryption_secret ~/.config/task/home-manager-taskrc   # -> 0

task _get rc.sync.encryption_secret | wc -c    # 65 (64 hex + newline)
task sync                                       # -> "Success!"
task count                                       # matches across all hosts
```

## 5. Deprecation

- **Rotate the client_id too (option B) if the old secret ever hit git in
  plaintext** — the old ciphertext/bucket is then fully orphaned.
- **Invalidate the old material:**
  - Option A: the WingTask data reset already discarded old-secret blobs.
  - Option B: delete the old client in the WingTask UI so its bucket is gone.
- **Clean local traces of the old secret:**
  ```sh
  rm ~/.local/share/task/taskchampion.sqlite3.pre-rotation      # each host
  nix-collect-garbage        # drop old store paths that referenced it
  ```
- The old plaintext value may still exist in **git history** (e.g. a
  previously-committed `local.nix`). History rewriting is disruptive; treat the
  rotation itself (old secret no longer decrypts any live bucket) as the
  mitigation.
