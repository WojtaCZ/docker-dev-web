# docker-dev-web

Web development specialisation of [docker-dev-template](https://github.com/WojtaCZ/docker-dev-template).

## What's added on top of the baseline

### Toolchain

| Tool | Purpose |
| ---- | ------- |
| PHP 8.x + Composer | Server-side development |
| MariaDB client | MySQL-compatible DB shell (`mysql` CLI) |
| PostgreSQL libs | `psql` client |
| SQLite | Lightweight local DB |
| Nginx | Local web server / reverse proxy |
| Deno | Alternative JS runtime |
| Bun | Fast JS runtime + package manager + bundler |
| Chromium | Headless browser for Playwright MCP |
| Redis client | Cache inspection |

Node.js and npm come from the base image.

### MCP servers (on top of baseline)

| Server | Launcher | Purpose |
| ------ | -------- | ------- |
| `playwright` | `npx @playwright/mcp` | Browser automation — navigate, click, screenshot, scrape |
| `fetch` | `uvx mcp-server-fetch` | Full-control HTTP requests, response inspection |
| `sqlite` | `uvx mcp-server-sqlite` | Query the local `/workspace/.dev.db` SQLite file |

Declared in `claude-web/settings.layer.json`, which contains **only these
three** — the entrypoint merges it over the template's baseline layer, so the
baseline servers (`github`, `git`, `context7`, `sequential-thinking`) do not
need restating and are picked up automatically.

Two details that were previously wrong and are now asserted in CI:

- `fetch` uses **`uvx`**, not `npx`. There is no
  `@modelcontextprotocol/server-fetch` package on npm (the registry returns
  404); the fetch server is Python, published on PyPI as `mcp-server-fetch`.
- Playwright is pointed at the system Chromium on the **command line**
  (`--executable-path /usr/bin/chromium --no-sandbox`). The
  `PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH` environment variable is not something
  Playwright reads.

## Backing services

The image ships DB *clients* but nothing to connect to. `docker-compose.yml`
brings up the servers so those clients — and the `db-schema-review` skill — can
inspect a live schema instead of reading migration files:

```bash
docker compose up -d          # mariadb, postgres, redis, mailpit
./scripts/dev-up.sh           # auto-joins the docker-dev-web network
docker compose down -v        # stop and wipe
```

Hostnames inside the container: `mariadb`, `postgres`, `redis`, `mailpit`.
Mailpit's web UI is at <http://localhost:8025>. All ports bind to `127.0.0.1`
only — these have development credentials and no hardening.

## The `web` task runner

The embedded leaves have `.mcu-profile.json` + `mcu`; this image has the same
thing for web work, so an agent never has to infer whether a project uses npm,
pnpm, bun, deno or composer.

```bash
web --init          # detect the stack from lockfiles, write .web-profile.json
web --list          # tasks and settings in this workspace
web --schema        # full key reference
web dev             # run the dev server
web build
web test
web lint
web typecheck
web e2e             # Playwright against the system Chromium
web migrate
```

`vscode-templates/tasks.json` drives the same keys, so Ctrl+Shift+B works
identically across projects.

## dev-doctor

```bash
dev-doctor           # table of every check
dev-doctor --json    # machine-readable; non-zero exit on any FAIL
```

This layer adds checks for PHP and its extensions, composer, deno, bun, nginx,
the DB clients, the `web` runner, the sqlite MCP database, and — importantly —
that **Chromium actually launches headless**, without which the Playwright MCP
is dead weight. CI runs it before anything is published.

### Skills (custom, baked into this image)

| Skill | Invoke with | Description |
| ----- | ----------- | ----------- |
| `php-modernize` | `/php-modernize` | Rewrite PHP to 8.x idioms (types, enums, match, readonly, fibers) |
| `db-schema-review` | `/db-schema-review` | Schema normalisation, indexes, constraints, migration safety |
| `rest-api-review` | `/rest-api-review` | Scored REST API review — HTTP semantics, resources, errors, security |
| `web-perf-audit` | `/web-perf-audit` | Core Web Vitals, bundle bloat, TTFB, rendering path |
| `design-tokens-setup` | `/design-tokens-setup` | Establish or audit design token system (colour, type, space, motion) |

`init`, `review`, `security-review` and `simplify` are Claude Code built-ins —
they are available here, but they are not inherited image content;
`docker-dev-template`'s `claude-baseline/skills/` is empty by design.

### Recommended: Anthropic design skills

The following built-in skills are ideal for web/design work and are already available if you have the Anthropic Claude Code extensions installed on the host (they'll be symlinked in via the shared `~/.claude` mount):

`frontend-design` · `critique` · `polish` · `adapt` · `animate` · `colorize` · `typeset` · `distill` · `onboard` · `harden` · `audit` · `optimize` · `arrange` · `bolder` · `quieter` · `delight` · `overdrive`

Run `/teach-impeccable` once per project to capture your design guidelines into the project's CLAUDE.md.

### VSCode extensions

`prettier` · `eslint` · `tailwindcss` · `intelephense` (PHP) · `typescript-next` · `errorlens` · `mysql-client` · `vite` · `playwright`

## Quick start

**VSCode:**
```powershell
code C:\code\my-web-project
# F1 → Dev Containers: Reopen in Container
```

**Headless CLI:**

Windows:
```powershell
.\scripts\dev-up.ps1
.\scripts\dev-up.ps1 -Workspace C:\code\my-site
.\scripts\dev-up.ps1 -Rebuild    # pull fresh base + rebuild
```

Linux/macOS:
```bash
./scripts/dev-up.sh
./scripts/dev-up.sh ~/code/my-site
DEV_REBUILD=1 ./scripts/dev-up.sh
```

Ports 3000, 5173 (Vite), 8000, 8080 are forwarded to the host automatically.

## Updating from base

This image uses `FROM ghcr.io/wojtacz/docker-dev-template:latest`. The `dev-up` scripts pass `--pull` by default, so every rebuild picks up the latest base. To skip the pull (offline / pinned):

```bash
DEV_NO_PULL=1 ./scripts/dev-up.sh
```

```powershell
.\scripts\dev-up.ps1 -NoPull
```

## Inheritance model

```
ghcr.io/wojtacz/docker-dev-template:latest   ← base (Arch, Claude Code, baseline skills/MCP)
         │
         └── ghcr.io/wojtacz/docker-dev-web:latest   ← this image
                  Adds: PHP, Bun, Deno, Chromium, Nginx, DB clients
                  Adds: playwright + fetch + sqlite MCP
                  Adds: php-modernize, db-schema-review, rest-api-review, web-perf-audit, design-tokens-setup
```

See the [base repo README](https://github.com/WojtaCZ/docker-dev-template#building-a-specialised-image) for the full propagation and pinning story.
