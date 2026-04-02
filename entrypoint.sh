#!/bin/bash
set -e

# Fix Docker socket permissions if mounted
if [ -S /var/run/docker.sock ]; then
    SOCK_GID=$(stat -c '%g' /var/run/docker.sock)
    CURRENT_DOCKER_GID=$(getent group docker | cut -d: -f3)
    if [ "$SOCK_GID" != "$CURRENT_DOCKER_GID" ]; then
        sudo groupmod -g "$SOCK_GID" docker
    fi
fi

# Ensure correct ownership of mounted .claude auth directory
if [ -d /home/claude/.claude ]; then
    sudo chown -R claude:claude /home/claude/.claude 2>/dev/null || true
fi

exec "$@"
