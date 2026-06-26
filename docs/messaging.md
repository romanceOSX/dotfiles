# Unified TUI messaging — WeeChat + Matrix

A single, vim-keybound terminal client for **WhatsApp** and **Discord**, with no
AI and no cloud processing. Every component runs locally (or on the always-on
`alien` node). WeeChat is the front end; a local Matrix homeserver (Conduit)
routes traffic; two `mautrix` bridges connect to the real networks.

```
  WeeChat (vim TUI) ──Matrix──► Conduit ──► mautrix-whatsapp ──► WhatsApp Web
                                        └──► mautrix-discord  ──► Discord API
```

## What this repo provides

| Piece | Where | Notes |
| --- | --- | --- |
| WeeChat + `weechat-matrix` | `home/messaging.nix` | python plugin pinned to 3.12 (matrix-nio is broken on 3.13). Installed on macOS + `alien` only. |
| Compose file + config templates | `home/messaging/` | symlinked to `~/.config/messaging/` |
| `messaging-stack` manager | `.local/bin/messaging-stack` | token gen, config render, container lifecycle |

The Conduit + bridge **containers** are not managed by Nix — they need a docker
daemon (Colima on macOS, native on Linux) and runtime-generated tokens, so
`messaging-stack` owns them. All runtime state lives in the gitignored data dir
`~/.local/share/messaging/`.

> `libolm` (pulled in by matrix-nio) is EOL upstream and marked insecure in
> nixpkgs; `flake.nix` permits `olm-3.2.16` consciously. The stack is local-only
> and unfederated, so the exposure is negligible.

## First-time setup

Requires a running docker daemon. On macOS: `colima start`. On `alien` Colima is
already a systemd user service.

```sh
messaging-stack setup            # local (macOS via Colima)
messaging-stack setup --host=alien   # on the always-on node instead
```

This generates appservice tokens, renders the Conduit + bridge configs, starts
the three containers, and waits for the bridges to write their
`registration.yaml`. It then prints the interactive WeeChat steps.

### Finish the wiring from WeeChat

Conduit registers appservices through its **admin room** (there is no file-drop
shortcut), so this part is a one-time manual ritual:

```text
weechat
  /script install vim_mode.py
  /matrix server add local localhost:6167
  /matrix connect local
  /matrix register <user> <password>          # first user becomes admin
```

Then open a chat with `@conduit:localhost`, send `register-appservice`, and paste
the contents of each registration file as a fenced code block:

```text
~/.local/share/messaging/whatsapp/registration.yaml
~/.local/share/messaging/discord/registration.yaml
```

Restart the bridges so they pick up the registration:

```sh
messaging-stack restart
```

### Log into the networks

```sh
messaging-stack login-whatsapp   # prints the QR-link steps
messaging-stack login-discord    # prints the QR / token steps
```

WhatsApp prints a QR code straight into the WeeChat buffer — scan it from
**WhatsApp → Linked Devices**. Discord supports QR (`login-qr`) or token login.

## Day-to-day

```sh
messaging-stack start | stop | restart | status | logs
```

All accept `--host=alien` to act on the always-on node instead of locally. When
the stack runs on `alien`, Conduit stays bound to `localhost` there; reach it
from this machine with an SSH tunnel:

```sh
messaging-stack tunnel           # forwards alien:6167 → localhost:6167
```

…then point WeeChat at `localhost:6167` as usual.

## Vim keys in WeeChat

`vim_mode.py` gives `Esc` for normal mode, `h/j/k/l` movement, `i` to insert,
and `:`-command mode. Buffers (Discord servers/DMs, WhatsApp chats) appear as
the numbered list — `gt`/`gT` or `Alt+→/←` to switch.
