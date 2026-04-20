#!/usr/bin/env bash
# Headless build + run for the web dev container on Linux/macOS.
#
# Usage:
#   ./scripts/dev-up.sh                   # workspace = $(pwd)
#   ./scripts/dev-up.sh /path/to/proj     # mount a specific project
#
# Env vars:
#   DEV_IMAGE=<name>       image tag              (default: dev-template-web)
#   DEV_CONTAINER=<name>   running container name (default: dev-web)
#   DEV_NO_BUILD=1         skip docker build
#   DEV_NO_PULL=1          don't --pull the base image (offline / pin)
#   DEV_REBUILD=1          docker build --no-cache

set -euo pipefail

IMAGE_NAME="${DEV_IMAGE:-dev-template-web}"
CONTAINER_NAME="${DEV_CONTAINER:-dev-web}"
WORKSPACE="${1:-$(pwd)}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ "${DEV_NO_BUILD:-0}" != "1" ]; then
    BUILD_FLAGS=()
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

# Expose typical web dev ports
PORTS=(-p 3000:3000 -p 5173:5173 -p 8000:8000 -p 8080:8080)

SSH_ARGS=()
case "$(uname -s)" in
    Darwin)
        SSH_ARGS=(-v /run/host-services/ssh-auth.sock:/ssh-agent
                  -e SSH_AUTH_SOCK=/ssh-agent)
        ;;
    Linux)
        if [ -n "${SSH_AUTH_SOCK:-}" ] && [ -S "$SSH_AUTH_SOCK" ]; then
            SSH_ARGS=(-v "$SSH_AUTH_SOCK:/ssh-agent"
                      -e SSH_AUTH_SOCK=/ssh-agent)
        else
            echo "WARN: SSH_AUTH_SOCK not set; git over SSH won't work." >&2
        fi
        ;;
esac

exec docker run --rm -it \
    --name "$CONTAINER_NAME" \
    --init \
    "${MOUNTS[@]}" \
    "${PORTS[@]}" \
    "${SSH_ARGS[@]}" \
    "$IMAGE_NAME"
