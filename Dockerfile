# syntax=docker/dockerfile:1.7
FROM ghcr.io/wojtacz/docker-dev-template:latest

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

# Install Playwright's system deps via its own helper (uses chromium above)
ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 \
    PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=/usr/bin/chromium

USER dev

# Bun — fast JS runtime and package manager
RUN curl -fsSL https://bun.sh/install | bash

ENV PATH="/home/dev/.bun/bin:/home/dev/.local/bin:${PATH}"

# Stack web-specific Claude config on top of the baseline baked by the parent image.
# Copying into skills/ adds to baseline skills; skills with the same name override.
# settings.json here replaces the baseline one — it re-declares all baseline MCPs
# plus the web-specific ones.
COPY --chown=dev:dev claude-web/skills/    /home/dev/.claude/skills/
COPY --chown=dev:dev claude-web/agents/    /home/dev/.claude/agents/
COPY --chown=dev:dev claude-web/commands/  /home/dev/.claude/commands/
COPY --chown=dev:dev claude-web/settings.json /home/dev/.claude/settings.json

WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["bash"]
