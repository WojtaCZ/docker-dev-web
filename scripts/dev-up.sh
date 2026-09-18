#!/usr/bin/env bash
# Headless build + run for the web dev container on Linux/macOS.
#
# Usage:
#   ./scripts/dev-up.sh                   # workspace = $(pwd)
#   ./scripts/dev-up.sh /path/to/project
#
# Env vars:
#   DEV_IMAGE=<name>       image tag              (default: dev-template-web)
#   DEV_CONTAINER=<name>   running container name (default: dev-web)
#   DEV_CHANNEL=stable     track the promoted template tag instead of :latest
#   DEV_NO_BUILD=1         skip docker build
#   DEV_NO_PULL=1          don't --pull the base image (offline / pin)
#   DEV_REBUILD=1          docker build --no-cache
#   DEV_NO_CACHE_VOLUMES=1 don't mount the persistent package caches
#   DEV_SKIP_UPDATE=1      skip `claude update` on container start
#   DEV_DOCTOR=1           run dev-doctor and exit
#   DEV_PORTS="3000 8080"  extra ports to publish on 127.0.0.1
#   DEV_NO_SERVICES=1      don't join the docker-compose service network
#   DEV_ASSETS=<path>      read-only mount at /opt/assets for licence-encumbered
#                          material (commercial fonts, private registry creds,
#                          proprietary design-system packages)

set -euo pipefail

IMAGE_NAME="${DEV_IMAGE:-dev-template-web}"
CONTAINER_NAME="${DEV_CONTAINER:-dev-web}"
WORKSPACE="${1:-$(pwd)}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ "${DEV_NO_BUILD:-0}" != "1" ]; then
    BUILD_FLAGS=(--build-arg "BASE_TAG=${DEV_CHANNEL:-latest}")
    [ "${DEV_NO_PULL:-0}" != "1" ] && BUILD_FLAGS+=("--pull")
    [ "${DEV_REBUILD:-0}" = "1" ]  && BUILD_FLAGS+=("--no-cache")
    docker build "${BUILD_FLAGS[@]}" -t "$IMAGE_NAME" "$REPO_ROOT"
fi

CLAUDE_JSON="$HOME/.claude.json"
CLAUDE_DIR="$HOME/.claude"
if [ ! -f "$CLAUDE_JSON" ]; then
    echo "WARN: $CLAUDE_JSON not found. Run 'claude' on the host at least once." >&2
fi
mkdir -p "$CLAUDE_DIR"

MOUNTS=(
    -v "$WORKSPACE:/workspace"
    -v "$CLAUDE_JSON:/host-claude-auth.json"
    -v "$CLAUDE_DIR:/host-claude-dir"
)

if [ "${DEV_NO_CACHE_VOLUMES:-0}" != "1" ]; then
    MOUNTS+=(
        -v "dev-cache-npm:/home/dev/.npm"
        -v "dev-cache-uv:/home/dev/.cache/uv"
        -v "dev-cache-bun:/home/dev/.bun/install/cache"
        -v "dev-cache-deno:/home/dev/.cache/deno"
        -v "dev-cache-composer:/home/dev/.cache/composer"
    )
fi

# Licence-encumbered material, following the pattern the Telink leaf uses for
# its EULA-restricted SDK: mount it, never bake it into the image.
if [ -n "${DEV_ASSETS:-}" ] && [ -d "$DEV_ASSETS" ]; then
    MOUNTS+=(-v "$DEV_ASSETS:/opt/assets:ro")
    echo "info: mounting assets from $DEV_ASSETS at /opt/assets"
fi

# Publish dev-server ports on loopback only.
PORT_ARGS=()
for p in ${DEV_PORTS:-}; do
    PORT_ARGS+=(-p "127.0.0.1:${p}:${p}")
done

# Join the backing-services network if `docker compose up -d` has been run.
NET_ARGS=()
if [ "${DEV_NO_SERVICES:-0}" != "1" ] && \
   docker network inspect docker-dev-web >/dev/null 2>&1; then
    NET_ARGS=(--network docker-dev-web)
    echo "info: joining the docker-dev-web service network (mariadb, postgres, redis, mailpit)"
elif [ "${DEV_NO_SERVICES:-0}" != "1" ]; then
    echo "info: backing services not running. Start them with: docker compose up -d"
fi

USER_ARGS=()
HOST_UID="$(id -u)"
HOST_GID="$(id -g)"
if [ "$HOST_UID" != "1000" ] || [ "$HOST_GID" != "1000" ]; then
    USER_ARGS=(--user 0:0 -e "HOST_UID=$HOST_UID" -e "HOST_GID=$HOST_GID")
fi

ENV_ARGS=()
[ "${DEV_SKIP_UPDATE:-0}" = "1" ] && ENV_ARGS+=(-e DEV_SKIP_UPDATE=1)
[ -n "${GITHUB_TOKEN:-}" ] && ENV_ARGS+=(-e "GITHUB_TOKEN=$GITHUB_TOKEN")

SSH_ARGS=()
case "$(uname -s)" in
    Darwin)
        SSH_ARGS=(-v /run/host-services/ssh-auth.sock:/ssh-agent -e SSH_AUTH_SOCK=/ssh-agent)
        ;;
    Linux)
        if [ -n "${SSH_AUTH_SOCK:-}" ] && [ -S "$SSH_AUTH_SOCK" ]; then
            SSH_ARGS=(-v "$SSH_AUTH_SOCK:/ssh-agent" -e SSH_AUTH_SOCK=/ssh-agent)
        else
            echo "WARN: SSH_AUTH_SOCK not set; git over SSH won't work." >&2
        fi
        ;;
esac

CMD_ARGS=()
[ "${DEV_DOCTOR:-0}" = "1" ] && CMD_ARGS=(dev-doctor)

exec docker run --rm -it \
    --name "$CONTAINER_NAME" \
    --init \
    "${MOUNTS[@]}" \
    "${PORT_ARGS[@]}" \
    "${NET_ARGS[@]}" \
    "${USER_ARGS[@]}" \
    "${ENV_ARGS[@]}" \
    "${SSH_ARGS[@]}" \
    "$IMAGE_NAME" "${CMD_ARGS[@]}"
