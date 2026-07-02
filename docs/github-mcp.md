# GitHub MCP server auth (Claude Code)

How the GitHub MCP server is wired into Claude Code on both nodes, and why the
"obvious" OAuth route does **not** work for it. Written up after a long
debugging session where every private-repo call returned `404 Not Found`.

The server is the official GitHub-hosted remote MCP at
`https://api.githubcopilot.com/mcp` (HTTP transport), registered at **user
scope** in `~/.claude.json`.

## TL;DR

- Auth is a **static `Authorization: Bearer <token>` header**, not interactive OAuth.
- The token **must have private-repo scope** (`repo`). A public-only token
  authenticates fine but 404s on every private repo.
- Simplest working token is the **`gh` CLI OAuth token** (`gh auth token`),
  which already carries the `repo` scope.

## Why not OAuth?

Claude Code's automatic OAuth flow relies on **Dynamic Client Registration**
(RFC 7591). GitHub's MCP server does not support DCR, so `/mcp` → Authenticate
fails with:

```
Failed to reconnect to github: Incompatible auth server: does not support dynamic client registration
```

There is no way around this from the client side — header-token auth is the
only working path for this endpoint.

## Symptoms of a wrong (public-only) token

A token can be valid yet scoped to public repos only. Signs:

| Check | Public-only token | Correct token |
| --- | --- | --- |
| `GET /user` (identity) | `200`, correct login | `200` |
| `GET /repos/<owner>/<private>` | `404 Not Found` | `200` |
| `search_repositories user:<me> is:private` | `0` results | lists private repos |
| `GET /user/repos?visibility=all` | only public repos (== `public_repos`) | all repos |

If reads work but issue/PR **create** 404s, the token type may be rejected for
writes — fall back to a classic PAT with `repo` scope.

## Setup (per machine)

```bash
TOKEN=$(gh auth token)            # gho_… , scopes must include 'repo'
claude mcp remove github --scope user 2>/dev/null
claude mcp add --transport http --scope user github \
  https://api.githubcopilot.com/mcp \
  --header "Authorization: Bearer $TOKEN"
# then, inside Claude Code:  /mcp  → reconnect github  (no OAuth prompt)
```

## alien

`alien` has `claude` but **not `gh`**, so it can't mint its own token. GitHub
OAuth tokens are not host-locked, so the setup there reuses **this Mac's** `gh`
token, piped over SSH without ever printing it:

```bash
gh auth token | ssh alien '
  read -r T
  claude mcp remove github --scope user >/dev/null 2>&1
  claude mcp add --transport http --scope user github \
    https://api.githubcopilot.com/mcp --header "Authorization: Bearer $T"
'
```

Consequence: alien is **pinned to the Mac's `gh` token**. If that token is
rotated (`gh auth logout`/`refresh`), alien goes stale too and this command must
be re-run. For isolation, give alien a dedicated classic PAT (`repo` scope)
instead.

## Caveats

- The token lands in `~/.claude.json` in **plaintext** — that file is `0600`,
  and is not part of this repo (nothing to commit).
- `gh` cannot list, create, or delete personal access tokens; there is no
  GitHub API for user-level PAT management. Do that in the web UI at
  `github.com/settings/tokens`.
- Rotating the `gh` token (or `gh auth logout`) invalidates the header on every
  machine using it — re-run the setup afterward.
