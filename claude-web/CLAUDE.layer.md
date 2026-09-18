
---

## Web layer (`docker-dev-web`)

Web development image. Branches off `docker-dev-template`, so the baseline layer
applies but **no embedded tooling is present**.

| Area | What is here |
|---|---|
| PHP | `php`, `php-fpm`, `php-sqlite`, `php-intl`, `php-gd`, `composer` |
| JS runtimes | `node`/`npm` (baseline), `deno`, `bun` (at `~/.bun/bin`, on `PATH`) |
| Databases | `sqlite`, `redis`, `mariadb-clients` (client only — no server), `postgresql-libs` (libs only — no server) |
| Web server | `nginx` |
| Browser | `chromium` at `/usr/bin/chromium` — the distro build, used instead of Playwright's own download (saves ~300 MB and stays pacman-patched) |

### Commands to prefer over ad-hoc shell

- **`web <key>`** — the project task runner, reading `.web-profile.json` from the
  workspace. **Use this instead of guessing whether the repo uses npm, pnpm,
  bun, composer or make.**
  - Task keys: `dev`, `build`, `start`, `test`, `testWatch`, `lint`, `format`,
    `typecheck`, `e2e`, `migrate`, `seed`, `deploy`, `clean`, `install`
  - `web --list` shows what this workspace actually defines
  - `web --init [stack]` detects the stack and writes a starter profile
  - `web --print <key>` shows a command without running it
  - `web --schema` shows the profile schema
  - Caveat: profile commands run through `bash -c`, i.e. arbitrary code
    execution from workspace content. Deliberate. Do not point it at an
    untrusted repo.
- **`dev-doctor`** — includes the web checks (`30-web.sh`).

### Playwright / Chromium

MCP servers from this layer: `playwright`, `fetch`, `sqlite`.

- `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1`, `PLAYWRIGHT_BROWSERS_PATH=/usr/lib/chromium`,
  `CHROMIUM_PATH=/usr/bin/chromium`.
- `PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH` is **not** a variable Playwright reads —
  the executable is chosen per launch. The MCP server takes it on the command
  line; the env vars above are only hints for scripts that read them deliberately.
- `--no-sandbox` is required running as non-root in a container. Consequence: a
  hostile page has the same reach as the `dev` user inside this container.
- The `sqlite` MCP server points at `/workspace/.dev.db`, created on first start
  by `web-post-create.sh`.
- VSCode starters: `/opt/web/vscode-templates/`.

### Skills in this layer

| Skill | Reach for it when |
|---|---|
| `db-schema-review` | Reviewing a schema, indexes, or migrations |
| `design-tokens-setup` | Setting up or auditing design tokens |
| `php-modernize` | Modernizing legacy PHP |
| `rest-api-review` | Reviewing REST API design |
| `web-perf-audit` | Page performance / Core Web Vitals work |

These are flat `~/.claude/skills/<name>.md` files and will **not** trigger on
their own — read the file directly when its topic comes up. See the maintenance
rule in the baseline layer.
