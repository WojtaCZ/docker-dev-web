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

| Server | Purpose |
| ------ | ------- |
| `playwright` | Browser automation — navigate, click, screenshot, scrape |
| `fetch` | Full-control HTTP requests, response inspection |
| `sqlite` | Query the local `/workspace/.dev.db` SQLite file |

Full baseline MCPs (`github`, `git`, `context7`, `sequential-thinking`) are also included.

### Skills (custom, baked into this image)

| Skill | Invoke with | Description |
| ----- | ----------- | ----------- |
| `php-modernize` | `/php-modernize` | Rewrite PHP to 8.x idioms (types, enums, match, readonly, fibers) |
| `db-schema-review` | `/db-schema-review` | Schema normalisation, indexes, constraints, migration safety |
| `rest-api-review` | `/rest-api-review` | Scored REST API review — HTTP semantics, resources, errors, security |
| `web-perf-audit` | `/web-perf-audit` | Core Web Vitals, bundle bloat, TTFB, rendering path |
| `design-tokens-setup` | `/design-tokens-setup` | Establish or audit design token system (colour, type, space, motion) |

Baseline skills (`init`, `review`, `security-review`, `simplify`, `less-permission-prompts`) are inherited.

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
