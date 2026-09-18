# syntax=docker/dockerfile:1.7
ARG BASE_TAG=latest
FROM ghcr.io/wojtacz/docker-dev-template:${BASE_TAG}

USER root

# Web development toolchain on top of the baseline Arch install
RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm --needed \
        php php-fpm php-sqlite php-intl php-gd \
        composer \
        mariadb-clients \
        postgresql-libs \
        sqlite \
        redis \
        nginx \
        deno \
        chromium \
    && pacman -Scc --noconfirm

# Chromium for Playwright. Using the distro build rather than Playwright's own
# download saves ~300 MB and keeps the browser patched by pacman.
#
# --no-sandbox is required when running as a non-root user inside a container;
# the container boundary is the security isolation layer. Note the consequence:
# a hostile page has the same reach as the `dev` user inside this container.
#
# PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH is NOT a variable Playwright reads — the
# executable is selected per-launch. The MCP server takes it on the command
# line instead (see the settings layer), and these are kept only as a hint for
# scripts that read them deliberately.
ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 \
    PLAYWRIGHT_BROWSERS_PATH=/usr/lib/chromium \
    CHROMIUM_PATH=/usr/bin/chromium

# The sqlite MCP server points at /workspace/.dev.db; create it on first start
# so the server has something to open.
COPY scripts/web-post-create.sh /usr/local/bin/web-post-create.sh
RUN chmod +x /usr/local/bin/web-post-create.sh

# dev-doctor checks contributed by this layer
COPY dev-doctor-checks/ /opt/dev-doctor/checks.d/
RUN chmod +x /opt/dev-doctor/checks.d/*.sh

# Profile task runner, so web projects get the same uniform, discoverable
# command surface the embedded leaves have (`web build`, `web test`, ...).
COPY run-web-task.sh /opt/web/run-web-task.sh
COPY web-profile.schema.json /opt/web/web-profile.schema.json
COPY vscode-templates/ /opt/web/vscode-templates/
RUN chmod +x /opt/web/run-web-task.sh && \
    ln -sf /opt/web/run-web-task.sh /usr/local/bin/web

USER dev

# Bun — fast JS runtime and package manager
RUN curl -fsSL https://bun.sh/install | bash

ENV PATH="/home/dev/.bun/bin:/home/dev/.local/bin:${PATH}"

# Stack web-specific Claude config on top of the baseline baked by the parent
# image. skills/agents/commands merge additively; settings are contributed as a
# numbered layer that the entrypoint merges, so this file declares only what the
# web image ADDS.
COPY --chown=dev:dev claude-web/skills/   /home/dev/.claude/skills/
COPY --chown=dev:dev claude-web/agents/   /home/dev/.claude/agents/
COPY --chown=dev:dev claude-web/commands/ /home/dev/.claude/commands/
COPY --chown=dev:dev claude-web/settings.layer.json \
     /home/dev/.claude-layers/20-web.json

# Memory layer: the web tool inventory, concatenated into ~/.claude/CLAUDE.md
# by entrypoint.sh.
COPY --chown=dev:dev claude-web/CLAUDE.layer.md \
     /home/dev/.claude-memory-layers/20-web.md

WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["bash"]
