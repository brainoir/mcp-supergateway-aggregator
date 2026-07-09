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
