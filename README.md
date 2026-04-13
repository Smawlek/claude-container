# claude-container

A Docker environment for running [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) in an isolated container. Packages Ubuntu 24.04 with Node.js 22, Python 3, and a full Docker engine (Docker-in-Docker) so the agent can develop and containerize applications without touching the host.

## Prerequisites

- **Docker** (with the Docker daemon running)
- **Git**

## Quick Start

```bash
make build
make run
```

Or equivalently with Docker Compose directly:

```bash
docker compose build
docker compose run --rm claude
```

This drops you into a bash shell inside the container. From there, run `claude` to start the CLI interactively, or `yolo-claude` for full auto mode (`--dangerously-skip-permissions`).

To mount a specific project directory:

```bash
PROJECT_PATH=/path/to/project make run
```

## Make Targets

| Target | Description |
|---|---|
| `make build` | Build the Docker image |
| `make run` | Start a bash shell in the container |
| `make claude` | Start Claude CLI interactively |
| `make yolo` | Start Claude CLI in full auto mode |
| `make shell` | Start a bash shell (alias for `run`) |
| `make clean` | Remove the built image and stopped containers |
| `make logs` | Show Docker daemon logs from inside the container |
| `make help` | Show all available targets |

## Security Model

### Docker-in-Docker Isolation

This environment uses **true Docker-in-Docker**: a separate Docker daemon runs inside the container. Any containers the agent creates are **nested** within the outer container, not siblings on your host. This means:

- The agent **cannot** access your host's Docker daemon or filesystem (beyond the mounted workspace).
- Nested containers are destroyed when the outer container exits.
- `--privileged` is required for the nested Docker daemon to manage cgroups/namespaces — it does not expose the host's Docker daemon.

### Full Auto Mode

Running `claude --dangerously-skip-permissions` (or the `yolo-claude` alias) inside the container is safe — the agent has full control over the container but cannot escape to the host. The only host path it can modify is the workspace you explicitly mounted.

### Sudo Access

The `claude` user has passwordless sudo (`NOPASSWD: ALL`) inside the container. This is acceptable because the container itself is the security boundary — the user cannot escape to the host.

## Architecture

| File | Purpose |
|---|---|
| `Dockerfile` | Ubuntu 24.04 + Node.js 22 + Python 3 + Docker engine + Claude CLI |
| `entrypoint.sh` | Starts the nested Docker daemon, fixes auth ownership, and symlinks `.claude.json` into the auth volume for persistence |
| `docker-compose.yml` | DinD setup with `--privileged`, exposes port 3030 |
| `Makefile` | Convenience targets for common operations |
| `auth/` | Mounted as `/home/claude/.claude` to persist auth tokens (gitignored) |
| `workspace/` | Default project mount point (gitignored) |

## Notes

- Auth tokens in `auth/` are gitignored. Never commit credentials.
- The entrypoint symlinks `~/.claude.json` into the `auth/` volume so authentication persists across container restarts.
- Port **3030** is forwarded from the container to the host for dev servers.
- Set `SKIP_DOCKER=1` env var to skip Docker daemon startup if you don't need Docker inside the container.
