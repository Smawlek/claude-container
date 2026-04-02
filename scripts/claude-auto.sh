#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PROJECT_PATH="${1:-$(pwd)}"

docker run -it --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v "$PROJECT_ROOT/auth":/home/claude/.claude \
  -v "$PROJECT_PATH":/workspace \
  claude-dev yolo-claude
