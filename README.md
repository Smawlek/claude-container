# docker-claude-web-dev

A Docker environment for running [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) in an isolated container. Packages Ubuntu 24.04 with Node.js 22, Python 3, and a full Docker engine (Docker-in-Docker) so the agent can develop and containerize applications without touching the host.

## Prerequisites

- **Docker** (with the Docker daemon running)
- **Git**

## Quick Start

```bash
docker compose build
docker compose run --rm claude
```

This drops you into a bash shell inside the container. From there, run `claude` to start the CLI interactively, or `claude --dangerously-skip-permissions` for full auto mode.

To mount a specific project directory:

```bash
PROJECT_PATH=/path/to/project docker compose run --rm claude
```

## Security Model

### Docker-in-Docker Isolation

This environment uses **true Docker-in-Docker**: a separate Docker daemon runs inside the container. Any containers the agent creates are **nested** within the outer container, not siblings on your host. This means:

- The agent **cannot** access your host's Docker daemon or filesystem (beyond the mounted workspace).
- Nested containers are destroyed when the outer container exits.
- `--privileged` is required for the nested Docker daemon to manage cgroups/namespaces — it does not expose the host's Docker daemon.

### Full Auto Mode

Running `claude --dangerously-skip-permissions` inside the container is safe — the agent has full control over the container but cannot escape to the host. The only host path it can modify is the workspace you explicitly mounted.

### Sudo Access

The `claude` user has restricted sudo for exactly three commands:
- `dockerd` — starting the nested Docker daemon
- `groupmod` — fixing group IDs at startup
- `chown` — fixing file ownership on mounted volumes

## Architecture

| File | Purpose |
|---|---|
| `Dockerfile` | Ubuntu 24.04 + Node.js 22 + Python 3 + Docker engine + Claude CLI |
| `entrypoint.sh` | Starts the nested Docker daemon and fixes auth directory ownership |
| `docker-compose.yml` | DinD setup with `--privileged` |
| `auth/` | Mounted as `/home/claude/.claude` to persist auth tokens (gitignored) |

## Notes

- Auth tokens in `auth/` are gitignored. Never commit credentials.
- Set `SKIP_DOCKER=1` env var to skip Docker daemon startup if you don't need Docker inside the container.
