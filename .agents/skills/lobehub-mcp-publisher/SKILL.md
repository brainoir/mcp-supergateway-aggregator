---
name: lobehub-mcp-publisher
description: Publish and manage MCP plugin (MCP server) listings on the LobeHub Marketplace using the lhm CLI (@lobehub/market-cli). Covers logging in via browser OIDC, connecting GitHub for ownership verification, submitting a new listing from your GitHub repository, claiming an existing plugin, authoring the lhm.plugin.json manifest, publishing new versions, and verifying the listing. Use when a user wants to submit, publish, update, release, claim, unpublish, or delete an MCP plugin or MCP server on lobehub.com or market.lobehub.com.
---

<!-- verified-against: @lobehub/market-cli@0.0.38; last-synced: 2026-06-15 -->

# Publish MCP Plugins to LobeHub Market

Publish, version, and manage MCP plugin listings on the LobeHub Marketplace via the `lhm` CLI.

- **Marketplace**: [lobehub.com/mcp](https://lobehub.com/mcp)
- **CLI package**: `@lobehub/market-cli` (npm, requires Node.js >= 22)

> **Important:** Always use the CLI commands below. Do NOT make raw HTTP/API requests — authentication uses OIDC PKCE with automatic token refresh, which the CLI handles for you.

## Skill Files

| File                           | URL                                                                |
| ------------------------------ | ------------------------------------------------------------------ |
| **SKILL.md** (this file)       | `https://market.lobehub.com/s/publish-mcp`                         |
| **references/manifest.md**     | `https://market.lobehub.com/s/publish-mcp/references/manifest`     |
| **references/lhm-commands.md** | `https://market.lobehub.com/s/publish-mcp/references/lhm-commands` |

Fetching the first URL returns this file with all references appended — one request gets everything.

**Install locally** with the CLI (`--agent` targets a specific agent: `claude-code`, `open-claw`, `codex`, `cursor`):

```bash
npx -y @lobehub/market-cli skills install lobehub-mcp-publisher --agent claude-code
```

Or with curl. The path below is the project-local Claude Code directory, matching the CLI's `--agent claude-code` target — swap in `./.agents/skills` (Codex), `./.cursor/skills` (Cursor), or `~/.claude/skills` for a user-global install:

```bash
SKILL_DIR=./.claude/skills/lobehub-mcp-publisher # project-local, same as the CLI default
mkdir -p "$SKILL_DIR/references"
curl -s https://market.lobehub.com/s/publish-mcp > "$SKILL_DIR/SKILL.md"
curl -s https://market.lobehub.com/s/publish-mcp/references/manifest > "$SKILL_DIR/references/manifest.md"
curl -s https://market.lobehub.com/s/publish-mcp/references/lhm-commands > "$SKILL_DIR/references/lhm-commands.md"
```

**Or just read them from the URLs above!**

## Critical Rules

1. **New listings are created with `lhm plugin submit <repo-url>`, not `lhm plugin publish`.** `lhm plugin publish` publishes a new _version_ of a plugin that already exists in the marketplace. If the plugin is not listed yet (it has no `lobehub.com/mcp/<identifier>` page and `lhm plugin claim` says "not claimable"), submit its GitHub repository with `lhm plugin submit <repo-url>` — the marketplace imports the repository as a new listing and assigns it to you (you must own the repo; import is asynchronous and takes a few minutes). Poll `lhm plugin list --output json` for the result, but **do not poll past ~10 minutes** — if nothing appeared the import failed silently; see the failure notes in [references/lhm-commands.md](references/lhm-commands.md). If the user does **not** own the repository, **stop** — only the repo owner can submit; anyone else must use the **Submit MCP** button at [lobehub.com/mcp](https://lobehub.com/mcp).
2. **Two commands require a human with a browser**: `lhm login` and `lhm github connect`. Never try to automate or bypass them — see [Interactive Steps](#interactive-steps-human-in-the-loop) below.
3. **Never read, print, or copy the credential files** in `~/.lobehub-market/`. They contain access and refresh tokens. Use `lhm auth status --output json` to inspect auth state instead.
4. **M2M credentials cannot publish.** `lhm register` and the `MARKET_CLIENT_ID` / `MARKET_CLIENT_SECRET` environment variables are an agent-identity channel for search, ratings, and comments (they are what the read-only `lhm mcp ...` commands authenticate with) — they have no publish permission. There is no token-only, non-interactive publish path; do not look for one.
5. Run commands as `npx -y @lobehub/market-cli ...`. `lhm` below is shorthand for the same binary (available after `npm install -g @lobehub/market-cli`).

## Prerequisites

- Node.js >= 22
- A LobeHub account (sign up at [market.lobehub.com](https://market.lobehub.com))
- A GitHub account that owns the plugin's source repository — both `plugin submit` and the claim scan match your GitHub username against the repo owner

## Workflow Overview

```bash
# 0. Probe current state (safe, read-only)
npx -y @lobehub/market-cli auth status --output json
npx -y @lobehub/market-cli github status

# 1. Log in (browser, human required) — skip if user.status is "authenticated" or "token expired"
npx -y @lobehub/market-cli login

# 2. Connect GitHub (browser, human required) — skip if already connected
npx -y @lobehub/market-cli github connect

# 3. Check ownership — is the plugin in your list?
npx -y @lobehub/market-cli plugin list --output json
#    Listed in the marketplace but not in your list? Claim it:
npx -y @lobehub/market-cli plugin claim joshuayoes-ios-simulator-mcp
#    Not in the marketplace at all? Submit your repo as a new listing
#    (async import, takes a few minutes — re-check with `plugin list`):
npx -y @lobehub/market-cli plugin submit https://github.com/joshuayoes/ios-simulator-mcp

# 4. Create or update lhm.plugin.json in the plugin directory
#    (same "version" = update that version in place; new "version" = new release)

# 5. Publish (always pass --dir as an absolute path)
npx -y @lobehub/market-cli plugin publish --dir /home/user/projects/my-mcp

# 6. Verify
npx -y @lobehub/market-cli plugin list --output json
#    Optional public check — `mcp ...` commands need the M2M identity from `lhm register` (Critical Rule 4)
npx -y @lobehub/market-cli mcp view joshuayoes-ios-simulator-mcp --output json
```

Notes on step 0: on a machine with no credentials at all, `auth status` exits with code 1 and prints `No credentials found...` — treat that as "not logged in", not as a failure. A `user.status` of `"token expired"` is usually fine: every command refreshes the token automatically; only re-login when a command actually fails with `Session expired`.

## Interactive Steps (Human-in-the-Loop)

`lhm login` and `lhm github connect` open a browser and block until the flow completes (login waits up to 5 minutes for the OAuth callback; github connect polls for up to 5 minutes).

Protocol for agents:

1. Probe first (`auth status --output json`, `github status`) — skip the interactive step entirely if already authenticated/connected.
2. Run the command in the foreground and immediately relay the fallback URL it prints (`If your browser does not open, visit: ...`) to the user, asking them to complete the authorization in their browser.
3. Wait for the command to exit, then confirm with the matching status command.
4. On timeout or failure, explain and ask the user before re-running. Do not retry in a loop — each retry opens another browser window.
5. Both commands are idempotent — re-running them after success is safe.

**Headless / SSH sessions:** `lhm login` listens for the OAuth callback on `localhost:51234`–`51243` _of the machine running the CLI_. If the user's browser is on a different machine, the callback cannot reach the CLI — forward a port first (`ssh -L 51234:localhost:51234 <host>`) or run `lhm login` on the user's local machine instead.

## The Manifest — lhm.plugin.json

`lhm plugin publish` reads `lhm.plugin.json` from the target directory. Minimal example:

```json
{
  "description": "Control the iOS Simulator from MCP",
  "identifier": "joshuayoes-ios-simulator-mcp",
  "name": "iOS Simulator MCP",
  "version": "1.4.0"
}
```

- `identifier`, `name`, and `version` are required. `identifier` is assigned by the marketplace when a server is first listed (via `lhm plugin submit` or the website) — copy it from the plugin's `lobehub.com/mcp/<identifier>` URL, find it in `lhm plugin list --output json`, or search with `lhm mcp search --q <keywords>` (needs the M2M identity, Critical Rule 4); never invent one.
- Re-publishing an existing `version` **merges** the supplied fields into that version — fields you omit keep their current values (the listing's README and install options are preserved). Use a **new** `version` for actual releases of the server; it starts from the previous latest version with your fields applied.
- `homepage` and `cloudEndpoint` are URL-validated but currently **not stored** by the publish endpoint — the listing keeps the values from its original import.
- Publishing marks the version **validated** (owner-published versions are trusted), so the listing drops the "Unvalidated" badge.
- The display **name / description / tags** are per-language. Your `name`/`description`/`tags` are the `en-US` source (verbatim, never machine-translated); other locales are translated from it automatically. To control a translation yourself, add a `localizations` array to the manifest, or use `lhm plugin i18n set` (see below). Owner-provided locales are authoritative and are never overwritten by the translator or a re-crawl.

Full field table, capability arrays (`tools` / `resources` / `prompts`), the `localizations` array, URL-validated fields, and complete examples: [references/manifest.md](references/manifest.md)

## Publish

```bash
npx -y @lobehub/market-cli plugin publish --dir /home/user/projects/my-mcp
```

Successful output:

```
✓ Authenticated as Jane Smith
  Reading lhm.plugin.json...
✓ Published joshuayoes-ios-simulator-mcp (1.3.0 → 1.4.0)
```

The CLI validates the manifest, verifies you own the plugin (via `plugin list`), and posts the version. A new version becomes the latest, and translations are generated automatically. Publishing the same `version` again updates that version in place (merge), so re-running after a partial failure is safe; bump `version` when the server itself has a new release.

## Verify & Manage

```bash
# Confirm the new version is live
npx -y @lobehub/market-cli plugin list --output json
# Optional public check (needs M2M identity from `lhm register`)
npx -y @lobehub/market-cli mcp view joshuayoes-ios-simulator-mcp --output json

# Delist / re-list
npx -y @lobehub/market-cli plugin unpublish joshuayoes-ios-simulator-mcp
npx -y @lobehub/market-cli plugin republish joshuayoes-ios-simulator-mcp

# Permanently delete (irreversible!)
npx -y @lobehub/market-cli plugin delete joshuayoes-ios-simulator-mcp --yes
```

`delete` is permanent and cannot be undone. `--yes` skips the CLI's confirmation prompt — only pass it after the user has explicitly confirmed the deletion in conversation.

## Errors

| Error                                                                                                | Cause                                                   | What to do                                                                                                                                                                                         |
| ---------------------------------------------------------------------------------------------------- | ------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| ``Not logged in. Run `lhm login` first.``                                                            | No user credentials                                     | Run `lhm login` (needs human, see Interactive Steps)                                                                                                                                               |
| ``Session expired. Run `lhm login` again.``                                                          | Refresh token expired                                   | Re-run `lhm login` (needs human); do not retry the failed command first                                                                                                                            |
| ``No credentials found. Run `lhm register` first or set MARKET_CLIENT_ID and MARKET_CLIENT_SECRET.`` | `mcp ...` commands use the M2M identity, not your login | Run `lhm register` once (see references/lhm-commands.md), or verify with `lhm plugin list` instead                                                                                                 |
| ``You don't own plugin "x". Use `lhm plugin claim x` first.``                                        | Plugin not in your owned list                           | Run `lhm plugin claim x` once, then retry publish                                                                                                                                                  |
| `Plugin "x" is not claimable`                                                                        | Not listed, GitHub not connected, or username mismatch  | Check `lhm github status`; check the identifier with `lhm mcp search --q ...`; if the plugin is not in the marketplace at all, submit it with `lhm plugin submit <repo-url>` (see Critical Rule 1) |
| `Submit failed: Repository owner "x" does not match your GitHub username "y" ...`                    | You can only submit repositories you own                | If the user owns the repo under another GitHub account, reconnect with `lhm github connect`; otherwise **stop** — see Critical Rule 1                                                              |
| `Submit failed: You must link and verify your GitHub account ...`                                    | GitHub not connected                                    | Run `lhm github connect` (needs human, see Interactive Steps)                                                                                                                                      |
| `lhm.plugin.json not found in <dir>`                                                                 | Wrong directory                                         | Pass `--dir` with the absolute path to the directory containing the manifest                                                                                                                       |
| 400 validation error on publish                                                                      | Invalid field (e.g. `authorUrl` is not a valid URL)     | Fix the field per [references/manifest.md](references/manifest.md), then retry once                                                                                                                |

Full per-command error tables: [references/lhm-commands.md](references/lhm-commands.md)

## Everything You Can Do

| Goal                     | Command                                                  | Interactive?            |
| ------------------------ | -------------------------------------------------------- | ----------------------- |
| Check auth state         | `lhm auth status --output json`                          | No                      |
| Log in                   | `lhm login`                                              | **Yes (browser)**       |
| Check GitHub connection  | `lhm github status`                                      | No                      |
| Connect GitHub           | `lhm github connect`                                     | **Yes (browser)**       |
| List owned plugins       | `lhm plugin list --output json`                          | No                      |
| Submit a new listing     | `lhm plugin submit <repo-url>`                           | No                      |
| Claim an existing plugin | `lhm plugin claim <identifier>`                          | No                      |
| Publish a new version    | `lhm plugin publish --dir <absolute-path>`               | No                      |
| List localizations       | `lhm plugin i18n list <identifier>`                      | No                      |
| Edit a localization      | `lhm plugin i18n set <identifier> --locale <locale> ...` | No                      |
| Remove a localization    | `lhm plugin i18n rm <identifier> --locale <locale>`      | No                      |
| Inspect a live listing   | `lhm mcp view <identifier> --output json`                | No                      |
| Find a listing           | `lhm mcp search --q <keywords>`                          | No                      |
| Delist / re-list         | `lhm plugin unpublish/republish <identifier>`            | No                      |
| Delete permanently       | `lhm plugin delete <identifier> --yes`                   | No (ask the user first) |

`mcp view` / `mcp search` authenticate with the M2M agent identity (run `lhm register` once); every other command above uses your user login.


---

<!-- verified-against: @lobehub/market-cli@0.0.38; last-synced: 2026-06-15 -->

# lhm Command Reference — MCP Publishing

Every command below runs as `npx -y @lobehub/market-cli <command>`; `lhm` is the global-install shorthand. Commands that support `--output json` should be run that way when a program needs to parse the result.

## login

Log in as a human user via OIDC PKCE browser flow. Opens a browser, listens on `localhost:51234`–`51243` for the OAuth callback (up to 5 minutes), then stores credentials in `~/.lobehub-market/user-credentials.json` (mode 0600).

```bash
npx -y @lobehub/market-cli login [--base-url https://market.lobehub.com]
```

```
Opening browser for authentication...
If your browser does not open, visit:
  https://market.lobehub.com/lobehub-oidc/auth?client_id=...

✓ Logged in as Jane Smith (jane@example.com)
```

Tokens auto-refresh on every subsequent command; re-login is only needed when a command fails with ``Session expired. Run `lhm login` again.``

`--base-url` targets a self-hosted or staging marketplace. The `MARKET_BASE_URL` environment variable does the same for `login` and the M2M commands (`mcp ...`, `auth ...`) only — `github ...` and `plugin ...` commands always use the base URL saved in the credentials file at login time, so re-run `lhm login` to switch marketplaces.

## logout

Remove the stored user credentials (M2M credentials are unaffected).

```bash
npx -y @lobehub/market-cli logout
```

## auth status

Show M2M and user authentication state. **Exits with code 1 when no credentials of either kind exist** — treat that as "not logged in".

```bash
npx -y @lobehub/market-cli auth status --output json
```

```json
{
  "m2m": { "status": "not configured" },
  "user": {
    "displayName": "Jane Smith",
    "email": "jane@example.com",
    "expiresAt": "2026-06-12T10:00:00.000Z",
    "status": "authenticated",
    "userId": "user_abc123"
  }
}
```

`user.status` is one of `authenticated`, `token expired`, or `not logged in`. `token expired` still publishes fine — commands refresh the token automatically. The `m2m` section is irrelevant to publishing: M2M credentials have no publish permission.

## github connect

Connect your GitHub account via OAuth. Required once before claiming or publishing — ownership is verified by matching your GitHub username against the plugin's repository owner. Opens a browser and polls every 2 seconds for up to 5 minutes.

```bash
npx -y @lobehub/market-cli github connect
```

```
Opening browser for GitHub OAuth...
If your browser does not open, visit:
  https://market.lobehub.com/api/connect/github/start?code=...

Waiting for GitHub authorization...

✓ GitHub connected as janedoe
```

Requires being logged in first. On timeout, re-run the command.

## github status / github disconnect

```bash
npx -y @lobehub/market-cli github status
# ✓ GitHub connected as janedoe
# ✗ GitHub not connected. Run `lhm github connect` to connect.

npx -y @lobehub/market-cli github disconnect
# ✓ GitHub disconnected
```

Disconnecting blocks new claims but already-claimed plugins remain yours.

## plugin list

List plugins owned by your account. Claimable-but-unclaimed plugins do **not** appear here — `lhm plugin claim <identifier>` discovers those through a separate claim scan.

```bash
npx -y @lobehub/market-cli plugin list --output json
```

Text output:

```
IDENTIFIER              NAME                LATEST VERSION  STATUS     CLAIMED
janedoe-weather-mcp     Weather MCP         2.0.1           published  yes
janedoe-db-mcp          DB MCP              -               published  no

2 plugin(s)
```

`CLAIMED: no` means the plugin was assigned to your account without an explicit claim (e.g. assigned at import time); you can still publish to it. With no plugins at all it prints ``No plugins found. Use `lhm plugin submit <gitUrl>` to list a new plugin, or `lhm plugin claim <identifier>` to claim an existing one.``

## plugin submit

Submit a GitHub repository you own as a **new** MCP plugin listing. The marketplace imports the repository, generates the listing, and assigns ownership to you. The repository must be recognizable as an MCP server — a clear README plus a `package.json` or a `.well-known/mcp/server.json` helps.

```bash
npx -y @lobehub/market-cli plugin submit https://github.com/janedoe/weather-mcp
```

```
✓ Authenticated as Jane Smith
✓ Submitted janedoe/weather-mcp for import

Your plugin repository has been submitted for import. The marketplace identifier
will be assigned during import; it will appear in your claimed assets once complete.

The import runs asynchronously and usually completes within a few minutes.
Track it with: lhm plugin list --output json
```

Requires login + GitHub connection, and the repository owner must match your GitHub username (org repos cannot be submitted through the CLI today — use the **Submit MCP** button at lobehub.com/mcp). Supports `--output json` (the `identifier` field is `null` for plugin submissions — the real identifier is assigned during import). Rate limited to 10 submissions per hour per account.

The import is **asynchronous**: poll `lhm plugin list --output json` (e.g. every 30s) until a new identifier appears — typically within a few minutes. The marketplace derives the identifier from the repository's manifest — do not assume it matches `owner-repo`. If the repository is already listed, the submit claims the existing listing for you instead of creating a duplicate. Re-submitting is safe (idempotent).

**Stop polling after ~10 minutes**: the submit command only confirms the submission was accepted; a failed import is not reported back to the CLI (there is no status command). If nothing appears, the likely causes are: the repository was not recognized as an MCP server (ensure it has a clear README and a `package.json` or `.well-known/mcp/server.json`), or its identifier is already taken by a listing pointing at a different repository. Re-submitting hits the same failure until the cause is fixed — fix the repo and retry once, or fall back to the **Submit MCP** button at lobehub.com/mcp and report the issue to the user.

## plugin claim

Claim ownership of a plugin that already exists in the marketplace.

```bash
npx -y @lobehub/market-cli plugin claim janedoe-weather-mcp
# ✓ Claimed ownership of plugin "janedoe-weather-mcp"
```

On failure:

```
Plugin "janedoe-weather-mcp" is not claimable. Make sure:
  1. The plugin exists in the marketplace
  2. Your GitHub account is connected (lhm github connect)
  3. Your GitHub username matches the plugin's author
```

Requires login + GitHub connection. The claim scan matches your GitHub username against the plugin's GitHub homepage URL — only a direct repo-owner match is discovered by the scan; org-repo collaborators with push/admin access cannot claim through the CLI today.

## plugin publish

Publish a new version from `lhm.plugin.json` (see [manifest.md](manifest.md)).

```bash
npx -y @lobehub/market-cli plugin publish --dir /home/user/projects/my-mcp
```

| Option         | Default           | Description                            |
| -------------- | ----------------- | -------------------------------------- |
| `--dir <path>` | current directory | Directory containing `lhm.plugin.json` |

Flow: parses the manifest → checks `identifier` / `name` / `version` are present → verifies the plugin is in your `plugin list` → posts the version. Success:

```
✓ Authenticated as Jane Smith
  Reading lhm.plugin.json...
✓ Published janedoe-weather-mcp (2.0.0 → 2.0.1)
```

Re-publishing the same `version` updates that version in place — supplied fields are merged, omitted fields keep their current values — so retrying after a partial failure is safe. Bump `version` when the server itself has a new release; the new version starts from the previous latest with your fields applied. The published version is also marked **validated** (drops the "Unvalidated" badge).

## plugin i18n (list / set / rm)

Manage the per-language **name / description / summary / tags** of a plugin version. `en-US` is the source of truth (your manifest `name`/`description`/`tags`); other locales are translated from it automatically. These commands let you override or correct any locale yourself — owner-provided locales are authoritative and are never overwritten by the translator or a re-crawl. All operate on the **latest** version unless you pass `--version`.

```bash
# List current localizations
npx -y @lobehub/market-cli plugin i18n list janedoe-weather-mcp

# Set/correct one locale from flags (only supplied fields change)
npx -y @lobehub/market-cli plugin i18n set janedoe-weather-mcp \
  --locale zh-CN --name "天气 MCP" --description "实时天气查询" --tags "天气,API"

# Set one or many locales from a JSON file (one object or an array of objects)
npx -y @lobehub/market-cli plugin i18n set janedoe-weather-mcp --file ./i18n.json

# Remove a locale (en-US cannot be removed — it is the source)
npx -y @lobehub/market-cli plugin i18n rm janedoe-weather-mcp --locale zh-CN
```

| Command                  | Key options                                                                                           | Notes                                                                                                                                           |
| ------------------------ | ----------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| `i18n list <identifier>` | `--version`, `--output json`                                                                          | Lists localizations of the target version                                                                                                       |
| `i18n set <identifier>`  | `--locale`, `--name`, `--description`, `--summary`, `--tags` (comma-separated), `--file`, `--version` | Merge: only supplied fields overwrite. A brand-new locale requires both `--name` and `--description`. Editing `en-US` also updates the listing. |
| `i18n rm <identifier>`   | `--locale` (required), `--version`                                                                    | Cannot remove `en-US`                                                                                                                           |

The `--file` payload is a localization object `{ "locale": "zh-CN", "name"?, "description"?, "summary"?, "tags"? }` or an array of them. Every object must include `locale`.

## plugin unpublish / republish

Delist or re-list a plugin (the listing and its versions are kept).

```bash
npx -y @lobehub/market-cli plugin unpublish janedoe-weather-mcp
# ✓ Plugin "janedoe-weather-mcp" has been delisted (unpublished)

npx -y @lobehub/market-cli plugin republish janedoe-weather-mcp
# ✓ Plugin "janedoe-weather-mcp" is now listed (published)
```

Both accept `--output json`.

## plugin delete

Permanently delete an owned plugin and all its versions. **Irreversible.**

```bash
npx -y @lobehub/market-cli plugin delete janedoe-weather-mcp --yes
# ✓ Plugin "janedoe-weather-mcp" has been permanently deleted
```

Without `--yes` the CLI prompts `Are you sure you want to permanently delete plugin "..."? This cannot be undone. [y/N]` on the TTY. Agents should pass `--yes` only after the user has explicitly confirmed the deletion in conversation.

## register (M2M agent identity)

One-time machine-to-machine registration; this is what the read-only `mcp ...` commands authenticate with. It has no publish permission and is independent of `lhm login`. Re-running on the same device returns the existing credentials — safe to repeat.

```bash
npx -y @lobehub/market-cli register --name "My Agent" --source claude-code
```

| Option          | Required | Description                                                         |
| --------------- | -------- | ------------------------------------------------------------------- |
| `--name`        | Yes      | A distinctive display name for the agent                            |
| `--source`      | No       | Agent platform (e.g. `claude-code`, `open-claw`, `codex`, `cursor`) |
| `--description` | No       | Short description of the agent                                      |

## mcp search / mcp view

Read-only marketplace queries — useful for finding the exact `identifier` and verifying a publish went live.

**These authenticate with M2M credentials, not your user login.** Run `lhm register --name <agent-name> --source <platform>` once (or set `MARKET_CLIENT_ID` / `MARKET_CLIENT_SECRET`) before using them; without M2M credentials they exit 1 with ``No credentials found. Run `lhm register` first or set MARKET_CLIENT_ID and MARKET_CLIENT_SECRET.`` If M2M is unavailable, verify a publish with `lhm plugin list --output json` instead.

```bash
npx -y @lobehub/market-cli mcp search --q "weather" --output json
npx -y @lobehub/market-cli mcp view janedoe-weather-mcp --output json
```

`mcp search` supports `--category`, `--sort`, `--order`, `--page`, `--page-size`, `--locale`. `mcp view` supports `--version`, `--locale`, and `-c, --comments`. Note: a plugin missing from public search/view does not prove the identifier is free — it may be delisted. Trust `plugin list` / `plugin claim` errors over `mcp view` 404s.

## Environment Variables

| Variable                                    | Purpose                                                                                                         |
| ------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| `MARKET_BASE_URL`                           | Overrides the base URL for `login` and M2M commands; `github`/`plugin` commands use the base URL saved at login |
| `MARKET_CLIENT_ID` / `MARKET_CLIENT_SECRET` | M2M agent identity, used by `mcp ...` commands (search/rate/comment only — **cannot publish**)                  |

## Error Reference

| Error                                                                                                | Exit | Retryable?                  | What to do                                                                                                                 |
| ---------------------------------------------------------------------------------------------------- | ---- | --------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| ``Not logged in. Run `lhm login` first.``                                                            | 1    | After login                 | Run `lhm login` (human + browser)                                                                                          |
| ``Session expired. Run `lhm login` again.``                                                          | 1    | After login                 | Run `lhm login` (human + browser)                                                                                          |
| ``No credentials found. Run `lhm register` ... or `lhm login` ...``                                  | 1    | After login                 | From `auth status` on a clean machine — run `lhm login`                                                                    |
| ``No credentials found. Run `lhm register` first or set MARKET_CLIENT_ID and MARKET_CLIENT_SECRET.`` | 1    | After register              | From `mcp ...` commands — run `lhm register` once, or verify with `plugin list` instead                                    |
| ``You don't own plugin "x". Use `lhm plugin claim x` first.``                                        | 1    | After claim                 | Run `lhm plugin claim x`, then retry publish once                                                                          |
| `Plugin "x" is not claimable`                                                                        | 1    | Only after fixing the cause | Check GitHub connection and identifier; if not listed at all, submit your repo with `lhm plugin submit <repo-url>`         |
| `Submit failed: Repository owner "x" does not match your GitHub username "y" ...`                    | 1    | Only after fixing the cause | You can only submit repos you own; reconnect the right account with `lhm github connect`, or use the website for org repos |
| `Submit failed: You must link and verify your GitHub account ...`                                    | 1    | After connect               | Run `lhm github connect` (human + browser)                                                                                 |
| `Submit failed: Too many repository submissions ...`                                                 | 1    | After ~1 hour               | Rate limited (10 submissions/hour/account) — wait before retrying                                                          |
| Submitted repo never appears in `plugin list` after ~10 min                                          | n/a  | After fixing the cause      | Import failed silently — see the failure notes in the `plugin submit` section above                                        |
| `lhm.plugin.json not found in <dir>`                                                                 | 1    | After fix                   | Pass `--dir` with the correct absolute path, or create the manifest                                                        |
| `Failed to parse lhm.plugin.json: ...`                                                               | 1    | After fix                   | Fix the JSON syntax error                                                                                                  |
| `lhm.plugin.json must include a/an "..." field.`                                                     | 1    | After fix                   | Add the missing `identifier` / `name` / `version` field                                                                    |
| 400 validation message naming a field                                                                | 1    | After fix                   | Fix the field per [manifest.md](manifest.md), retry once                                                                   |
| 5xx / network errors                                                                                 | 1    | Once                        | Retry once; if it persists, stop and report to the user                                                                    |


---

<!-- verified-against: @lobehub/market-cli@0.0.38; last-synced: 2026-06-15 -->

# lhm.plugin.json Reference

Complete schema for the manifest consumed by `lhm plugin publish`. The server validates the request body with the same rules listed here; invalid fields fail the publish with a 400 error.

## Fields

| Field           | Type       | Required     | Constraints                                | Description                                                                                                              |
| --------------- | ---------- | ------------ | ------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------ |
| `identifier`    | `string`   | Yes (by CLI) | Must match an existing marketplace listing | Assigned by the marketplace when the server is first listed — copy it, never invent one. Sent in the URL, not the body   |
| `name`          | `string`   | Yes          | Non-empty                                  | Display name shown in the marketplace                                                                                    |
| `version`       | `string`   | Yes          | Non-empty; must not already exist          | Version label for this release; semantic versioning recommended (`1.4.0`)                                                |
| `author`        | `string`   | No           | —                                          | Author display name                                                                                                      |
| `authorUrl`     | `string`   | No           | Must be a valid URL                        | Author profile URL (e.g. GitHub profile)                                                                                 |
| `category`      | `string`   | No           | —                                          | Marketplace category name                                                                                                |
| `cloudEndpoint` | `string`   | No           | Must be a valid URL; **not stored**        | Accepted and validated, but currently discarded on publish                                                               |
| `description`   | `string`   | No           | —                                          | Short description of what the plugin does                                                                                |
| `homepage`      | `string`   | No           | Must be a valid URL; **not stored**        | Accepted and validated, but currently discarded on publish                                                               |
| `icon`          | `string`   | No           | —                                          | Icon (emoji or image URL)                                                                                                |
| `localizations` | `object[]` | No           | Each item needs a `locale`                 | Owner-provided translations (see [Localizations](#localizations-i18n)). en-US is the source and also updates the listing |
| `prompts`       | `object[]` | No           | Array of objects                           | MCP prompt template definitions                                                                                          |
| `resources`     | `object[]` | No           | Array of objects                           | MCP resource definitions                                                                                                 |
| `tags`          | `string[]` | No           | Array of strings                           | Search/discovery tags                                                                                                    |
| `tools`         | `object[]` | No           | Array of objects                           | MCP tool definitions (standard MCP tool shape: `name`, `description`, `inputSchema`)                                     |

Unknown extra fields are silently stripped by the server. Note that `homepage` and `cloudEndpoint` are URL-validated but **not stored** by the publish endpoint — the homepage/endpoint shown in the marketplace comes from the plugin's original listing, not from `lhm plugin publish`.

## Capability Flags

The marketplace derives the listing's capability badges from the manifest: a non-empty `tools` array sets the "tools" capability, and likewise for `resources` and `prompts`. To advertise what your MCP server can do, declare the actual definitions — there is no separate capabilities field.

## Localizations (i18n)

The marketplace shows a per-language **name / description / summary / tags**. `en-US` is the **source of truth** — it holds your declared `name`/`description`/`tags` verbatim and is never machine-translated. Every other locale is translated from it automatically in the background.

You can override any locale yourself in two ways:

- **Inline in `lhm.plugin.json`** — add a `localizations` array; it is applied on `lhm plugin publish`.
- **Standalone, without republishing** — `lhm plugin i18n set <identifier> --locale zh-CN --name ...` (see [references/lhm-commands.md](lhm-commands.md)).

Each localization object: `{ "locale": "zh-CN", "name"?, "description"?, "summary"?, "tags"? }`. Only the fields you supply overwrite; creating a brand-new locale requires both `name` and `description`. Owner-provided locales are authoritative — the background translator only fills the locales you have **not** provided, and a re-crawl never overwrites them.

```json
{
  "description": "A UniProt protein database MCP server",
  "identifier": "fzlzjerry-uniprot",
  "localizations": [
    {
      "description": "UniProt 蛋白质数据库 MCP 服务器",
      "locale": "zh-CN",
      "name": "UniProt 蛋白质数据库"
    }
  ],
  "name": "UniProt",
  "version": "0.1.0"
}
```

## What Happens on Publish

1. An unknown `identifier` fails with `Plugin "x" not found` (the CLI normally catches this earlier as `You don't own plugin "x"`)
2. Ownership is verified; for unowned plugins an automatic claim via your connected GitHub account is attempted (owner match, or push/admin access on the repo) — failure is rejected. The CLI's own ownership pre-check normally exits before this path is reached
3. If the `version` already exists, the supplied fields are merged into that version (omitted fields keep their current values); otherwise a new version is created, starting from the previous latest version with your fields applied, and marked as the latest
4. The published version is marked **validated** (owner-published versions are trusted), so the listing no longer shows "Unvalidated"
5. Any supplied `localizations` are applied, then translations for the remaining locales are generated automatically in the background — they do not block or fail the publish

## Examples

### Minimal

```json
{
  "description": "Control the iOS Simulator from MCP",
  "identifier": "joshuayoes-ios-simulator-mcp",
  "name": "iOS Simulator MCP",
  "version": "1.4.0"
}
```

### Cloud-hosted MCP server with tools

```json
{
  "author": "Jane Smith",
  "authorUrl": "https://github.com/janedoe",
  "cloudEndpoint": "https://weather-mcp.example.com/mcp",
  "description": "Real-time weather lookups for any city",
  "homepage": "https://github.com/janedoe/weather-mcp",
  "identifier": "janedoe-weather-mcp",
  "name": "Weather MCP",
  "tags": ["weather", "api"],
  "tools": [
    {
      "name": "get_weather",
      "description": "Get current weather for a city",
      "inputSchema": {
        "type": "object",
        "properties": { "city": { "type": "string" } },
        "required": ["city"]
      }
    }
  ],
  "version": "2.1.0"
}
```

### Full

```json
{
  "author": "Jane Smith",
  "authorUrl": "https://github.com/janedoe",
  "category": "development",
  "cloudEndpoint": "https://my-mcp.example.com/mcp",
  "description": "Browse, query, and edit project databases over MCP",
  "homepage": "https://github.com/janedoe/db-mcp",
  "icon": "🗄️",
  "identifier": "janedoe-db-mcp",
  "name": "DB MCP",
  "prompts": [
    {
      "name": "explain_schema",
      "description": "Explain the schema of a connected database"
    }
  ],
  "resources": [
    {
      "name": "schema",
      "description": "Live database schema",
      "uri": "db://schema"
    }
  ],
  "tags": ["database", "sql"],
  "tools": [
    {
      "name": "run_query",
      "description": "Run a read-only SQL query",
      "inputSchema": {
        "type": "object",
        "properties": { "sql": { "type": "string" } },
        "required": ["sql"]
      }
    }
  ],
  "version": "3.0.0"
}
```

## Common Manifest Errors

| Symptom                                               | Fix                                                                                       |
| ----------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| `lhm.plugin.json must include an "identifier" field.` | Add `identifier` matching the marketplace listing                                         |
| `lhm.plugin.json must include a "name" field.`        | Add a non-empty `name`                                                                    |
| `lhm.plugin.json must include a "version" field.`     | Add a non-empty `version`                                                                 |
| `Failed to parse lhm.plugin.json: ...`                | Fix the JSON syntax error reported in the message                                         |
| 400 with a validation message mentioning a URL field  | `authorUrl`, `cloudEndpoint`, and `homepage` must be absolute, valid URLs (`https://...`) |
| 400 mentioning `tools` / `resources` / `prompts`      | These must be arrays of objects, not a single object or strings                           |
