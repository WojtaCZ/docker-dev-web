# docker-dev-web — Functional Writeup

> Non-embedded leaf. Inherits `docker-dev-template` directly.
> Fleet-wide architecture: [`docker-dev-embedded-base/WRITEUP.md`](../docker-dev-embedded-base/WRITEUP.md)

> **Note:** the analysis below describes the repo *as it was audited* on
> 2026-09-02. Every defect listed has since been fixed and every proposal
> implemented — see **Status: implemented** at the end for the mapping. The
> analysis is kept because it records *why* the current design is the way it is.


## 1. Purpose and position

The proof that the fleet's layering scheme is not embedded-specific: a web
development container built on exactly the same template, sharing the same host
Claude auth, but carrying a completely disjoint skill and MCP set.

```
docker-dev-template
  ├── docker-dev-embedded-base → arm / wch
  ├── docker-dev-embedded-telink
  └── docker-dev-web            ← THIS IMAGE
```

## 2. What this image adds

| Category | Contents |
| --- | --- |
| PHP stack | `php`, `php-fpm`, `php-sqlite`, `php-intl`, `php-gd`, `composer` |
| Databases | `mariadb-clients`, `postgresql-libs`, `sqlite`, `redis` (clients only — no servers run in-image) |
| Web server | `nginx` |
| JS runtimes | `deno` (pacman), `bun` (official installer → `~/.bun/bin`); `node`/`npm` inherited from the template |
| Browser | `chromium` — used by Playwright instead of Playwright's own download |
| Claude skills (5) | `php-modernize`, `db-schema-review`, `rest-api-review`, `web-perf-audit`, `design-tokens-setup` |
| MCP servers (+3) | `playwright`, `fetch`, `sqlite` on top of the four baseline |

### The Playwright arrangement

Rather than let Playwright download its own ~300 MB browser bundle, the image
installs Arch's `chromium` and points Playwright at it:

```dockerfile
ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 \
    PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=/usr/bin/chromium \
    PLAYWRIGHT_LAUNCH_OPTIONS_ARGS="--no-sandbox,--disable-setuid-sandbox"
```

`--no-sandbox` is required because Chromium's own sandbox needs privileges the
non-root `dev` user does not have. The Dockerfile comment states the reasoning
explicitly — the container is the isolation boundary. That is a defensible call
here, though it does mean a hostile page has the same reach as the `dev` user.

## 3. Verified defects

Checked against the live npm registry and PyPI on 2026-09-02.

| # | Severity | Finding |
| --- | --- | --- |
| **X1** | **High** | `settings.json` declares `fetch` as `npx -y @modelcontextprotocol/server-fetch`. **That npm package does not exist** — the registry returns 404. The fetch MCP is Python-only. Fix: `{"command": "uvx", "args": ["mcp-server-fetch"]}` (verified present on PyPI). The same bug is copied into `embedded-base` and `arm`. |
| X2 | Medium | `docker-dev-template`'s CI dispatch fan-out targets `embedded-base` and `telink` only — **this repo is not in it**, so it never rebuilds when the template changes. Add it, or document that it is refreshed manually. |
| X3 | Medium | `PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH` and `PLAYWRIGHT_LAUNCH_OPTIONS_ARGS` are not standard Playwright environment variables — Playwright reads `PLAYWRIGHT_BROWSERS_PATH` and takes an `executablePath` in `launch()`. `@playwright/mcp` accepts `--executable-path` on the command line. Verify these actually take effect; if not, pass `--executable-path /usr/bin/chromium --no-sandbox` in the MCP `args` instead. |
| X4 | Low | `redis` installs the full server package to get `redis-cli`; the README lists it as "Redis client". Harmless, but `redis` pulls a systemd unit and user that will never be used. |
| X5 | Low | `mcp-server-sqlite` points at `/workspace/.dev.db`, a file that will not exist in a fresh workspace. The server may fail to start. Create it in `post-create.sh` or make the path configurable. |
| X6 | Low | The README claims baseline skills `init`, `review`, `security-review`, `simplify`, `less-permission-prompts` are "inherited" — but `docker-dev-template`'s `claude-baseline/skills/` contains only a `.gitkeep`. Those are Claude Code built-ins, not inherited image content. Reword to avoid the implication that the template ships them. |
| X7 | Low | Same `settings.json` whole-file-replacement duplication as the rest of the fleet — this repo re-declares all four baseline MCPs verbatim. |

## 4. Proposed features

### 4.1 Fix the `fetch` MCP (X1)

One-line change, and it is currently a silently broken tool in three images.

### 4.2 Add this repo to the template's CI fan-out (X2)

### 4.3 Service containers instead of clients-only

Right now you get `mysql`/`psql`/`redis-cli` but nothing to connect to. A
`docker-compose.yml` alongside `dev-up.sh` that brings up MariaDB, Postgres, and
Redis on a shared network would make the DB clients actually useful — and
`db-schema-review` far more capable, since it could inspect a live schema rather
than reading migration files.

### 4.4 Match the embedded fleet's profile-runner pattern

The embedded leaves have `.mcu-profile.json` + `run-profile-task.sh` + a
chip-agnostic `tasks.json`. The web image has no equivalent. A
`.web-profile.json` with `dev`, `build`, `test`, `lint`, `e2e`, `migrate` keys
would give Claude the same uniform, discoverable command surface here.

### 4.5 A `dev-doctor` equivalent

Same proposal as the template's §5.5: assert PHP/composer/bun/deno/chromium all
resolve, Playwright can launch, and the MCP servers start. Would have caught X1.

### 4.6 Reuse the fleet's licence-mount pattern

The Telink leaf's "mount the vendor SDK read-only" approach applies here too, for
anything licence-encumbered (commercial fonts, private npm registries,
proprietary design-system packages).

---

## Status: implemented 2026-09-02

Everything proposed in section 4 is now in the repo, and every defect in
section 3 is fixed.

| Item | Resolution |
| --- | --- |
| X1 — `@modelcontextprotocol/server-fetch` does not exist on npm | `uvx mcp-server-fetch`; asserted in `tests/smoke.sh` |
| X2 — not in the template's CI fan-out | added, and this repo reports `downstream-verified` back |
| X3 — Playwright env vars it does not read | `--executable-path /usr/bin/chromium --no-sandbox` passed to the MCP server on the command line; the smoke test asserts both, and `dev-doctor` actually launches Chromium headless |
| X4 — `redis` server package for a client | left deliberately: `redis-cli` has no separate Arch package, and the real fix was giving you a **server to talk to** (see 4.3) |
| X5 — sqlite MCP pointed at a non-existent file | `scripts/web-post-create.sh` creates `/workspace/.dev.db` and git-excludes it |
| X6 — README implied built-in skills were inherited | reworded |
| X7 — settings duplication | additive layer; `claude-web/settings.layer.json` declares only the three servers this image adds |
| 4.3 — backing services | `docker-compose.yml`: mariadb, postgres, redis, mailpit; `dev-up.sh` auto-joins the network |
| 4.4 — profile-runner parity | `.web-profile.json` plus the `web` runner, `web --init` stack detection, and VSCode tasks |
| 4.5 — dev-doctor | `dev-doctor-checks/30-web.sh` |
| 4.6 — licence-mount pattern | `DEV_ASSETS` mounted read-only at `/opt/assets` |
