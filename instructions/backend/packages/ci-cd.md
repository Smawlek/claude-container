# CI/CD Rules

## Architecture
- Each environment runs on its own dedicated Hetzner VPS as a single-node Docker Swarm
- Staging VPS and production VPS are fully isolated — staging issues never affect production
- Caddy runs as a reverse proxy on each VPS via `caddy-shared-swarm` external network
- Secrets are managed as Docker Swarm external secrets, created from GitHub Actions secrets at deploy time
- Blue-green deployment is achieved via Swarm's `start-first` update order — zero downtime

## Branch strategy
- `main` → deploys to production automatically on merge
- `staging` → deploys to staging automatically on merge
- All feature work is done on feature branches: `feature/description`, `fix/description`, `chore/description`
- Feature branches merge into `staging` first — never directly into `main`
- `main` is updated only by merging `staging` after it has been verified on staging environment
- Never force push to `main` or `staging`
- Never commit directly to `main` or `staging` — always go through a PR

## GitHub Actions structure
- Workflows live in `.github/workflows/`
- Three workflow files:
  - `ci.yml` — runs on every PR and push to any branch: lint, test, build, security scan
  - `deploy-staging.yml` — runs on push to `staging`
  - `deploy-production.yml` — runs on push to `main`
- Never put deployment logic in `ci.yml` — keep CI and CD separated

## CI workflow (ci.yml)
Runs on: every push and PR to any branch
Steps in order:
1. Checkout code
2. Set up Node.js version from `package.json` engines field
3. Install dependencies via `npm ci` — never `npm install` in CI
4. Run ESLint — fail on any error
5. Run Prettier check — fail on any formatting issue
6. Run unit tests with coverage — fail if below 80%
7. Run e2e tests against local Docker PostgreSQL
8. Build the NestJS app — fail on any TypeScript error
9. Scan Docker image for vulnerabilities via Trivy — fail on CRITICAL severity
- All steps must pass before a PR can be merged — no exceptions
- Never skip or bypass CI checks to merge faster

## Docker image
- Every deployment builds a fresh Docker image — never deploy without rebuilding
- Images are tagged with the full Git SHA:
- Use GitHub Container Registry (ghcr.io) — authenticate via `GITHUB_TOKEN`
- Multi-stage Dockerfile — builder stage and lean production stage:
```dockerfile
  FROM node:22-alpine AS builder
  WORKDIR /app
  COPY package*.json ./
  RUN npm ci
  COPY . .
  RUN npm run build

  FROM node:22-alpine AS production
  WORKDIR /app
  COPY package*.json ./
  RUN npm ci --only=production
  COPY --from=builder /app/dist ./dist
  EXPOSE 3000
  CMD ["node", "dist/main.js"]
```
- Never include `.env` files or secrets in the Docker image
- Always use a specific Node.js version tag — never use `latest`
- Scan every built image with Trivy before pushing to ghcr.io:
```yaml
  - name: Scan image for vulnerabilities
    uses: aquasecurity/trivy-action@master
    with:
      image-ref: ghcr.io/{org}/{app}:{git-sha}
      severity: CRITICAL
      exit-code: 1
```
- Fix or document any CRITICAL vulnerability before proceeding — never deploy a vulnerable image

## VPS security hardening
Apply these rules to every new Hetzner VPS before deploying anything:

### Firewall
- Only three ports exposed publicly:
  - `22` — SSH (restrict to your IP range if possible)
  - `80` — HTTP (Caddy handles redirect to HTTPS)
  - `443` — HTTPS (Caddy terminates TLS)
- All other ports must be blocked including `2375`, `2376` (Docker), `5432` (PostgreSQL), `6379` (Redis)
- Configure via Hetzner Cloud Firewall — applied at network level before traffic reaches the VPS:
- Internal services (Redis, PostgreSQL, BullMQ dashboard) communicate via Docker internal networks only — never exposed to host network

### SSH hardening
- SSH key authentication only — disable password login immediately on VPS creation:
- Never use root user for deployments — create a dedicated deploy user with sudo only where needed
- GitHub Actions connects via SSH using a dedicated deploy key stored as a GitHub Actions secret
- Rotate SSH keys immediately if accidentally exposed

### Fail2Ban
- Install Fail2Ban on every VPS immediately after creation:
```bash
  apt install fail2ban -y
```
- Default jail configuration for SSH:
```ini
  [sshd]
  enabled = true
  port = 22
  maxretry = 5
  bantime = 3600
  findtime = 600
```
- Never disable Fail2Ban — if SSH port needs changing, update the jail config

### Docker security
- Never expose the Docker socket publicly
- Never run application containers as root — use a non-root user in Dockerfile:
```dockerfile
  RUN addgroup -S appgroup && adduser -S appuser -G appgroup
  USER appuser
```
- Docker Swarm manager socket is accessible only to the deploy user on the VPS
- Never mount the Docker socket into application containers

## Caddy configuration
- Caddy runs as a Docker Swarm service on each VPS connected to `caddy-shared-swarm` external network
- Caddy handles: automatic HTTPS via Let's Encrypt, HTTP to HTTPS redirect, reverse proxy to app containers
- Caddyfile lives on the VPS at `/etc/caddy/Caddyfile` — managed manually or via config management
- Every new project added to a VPS requires a new Caddyfile block:
Where `app_web` is the Docker Swarm service name (`{stack-name}_{service-name}`)
- Reload Caddy after every Caddyfile change — never restart:
```bash
  docker exec caddy caddy reload --config /etc/caddy/Caddyfile
```
- Never expose app container ports directly to the host — always route through Caddy
- Always verify HTTPS is working after adding a new project before considering deployment complete
- Caddy stores Let's Encrypt certificates in a named Docker volume — never delete this volume

### Caddy Docker setup
- Caddy runs as a stack on the Swarm with access to the Docker socket for service discovery:
```yaml
  caddy:
    image: caddy:2-alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /etc/caddy/Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy_data:/data
      - caddy_config:/config
    networks:
      - caddy-shared-swarm
```
- `caddy-shared-swarm` is created once per VPS and never recreated:
```bash
  docker network create --driver overlay --attachable caddy-shared-swarm
```
- Every app stack must connect to `caddy-shared-swarm` — never create per-app proxy networks

## Secret naming convention
- Every secret is namespaced with a short SHA suffix to allow blue-green simultaneous runs:
- `SHORT_SHA_SAFE` is the first 7 characters of the Git SHA with non-alphanumeric characters replaced
- This ensures old and new containers can run simultaneously during deployment without secret conflicts
- Secrets are created in Docker Swarm on the target VPS from GitHub Actions secrets at deploy time:
```bash
  echo "${{ secrets.PROD_DATABASE_URL }}" | docker secret create DATABASE_URL_${SHORT_SHA_SAFE} -
```
- After successful deployment, old secrets from the previous SHA are deleted from Swarm
- Staging secrets are prefixed with `STAGING_` in GitHub Actions secrets
- Production secrets are prefixed with `PROD_` in GitHub Actions secrets

## Environment-specific variables
These variables differ between staging and production and must never be shared:
- `DATABASE_URL` — separate Supabase PostgreSQL instances per environment
- `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_JWT_SECRET` — separate Supabase projects
- `CLIENT_URL`, `SERVER_URL` — different domains per environment
- `REDIS_URL` — separate Redis instance per VPS
- `NODE_ENV` — `staging` or `production`
- All third-party credentials — use test/sandbox accounts on staging, live accounts on production

## Docker stack file
- Stack file is `docker-stack.yml` — generated at deploy time with substituted variables
- Stack file uses Docker Swarm secrets for all sensitive values — never plain environment variables for secrets:
```yaml
  secrets:
    MY_SECRET_${SHORT_SHA_SAFE}: { external: true }
  environment:
    - MY_SECRET=/run/secrets/MY_SECRET_${SHORT_SHA_SAFE}
```
- Non-sensitive runtime config (PORT, NODE_ENV, GIT_COMMIT_HASH, REDIS_URL) are plain environment variables
- Swarm update config must always be:
```yaml
  update_config:
    order: start-first
    parallelism: 1
    failure_action: pause
    monitor: 30s
```
- Always set `stop_grace_period: 60s` — never kill containers mid-request

## Health check
- Every NestJS app must expose `/api/health/live` returning `200 OK`
- Health check verifies: app is running, database connection alive, Redis connection alive
- Health check is defined in the stack file:
```yaml
  healthcheck:
    test: ["CMD", "node", "-e",
      "fetch('http://127.0.0.1:{PORT}/api/health/live').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"]
    interval: 10s
    timeout: 3s
    retries: 6
    start_period: 25s
```
- Swarm will not route traffic to the new container until health check passes
- If health check never passes, `failure_action: pause` halts deployment — old container keeps running

## Database migration safety
- Never run migrations directly against production or staging — always via the deployment pipeline
- Dry run migrations in CI against the local test database to catch SQL errors before they reach any environment:
```bash
  npx prisma migrate diff \
    --from-schema-datasource prisma/schema.prisma \
    --to-schema-datamodel prisma/schema.prisma \
    --script > migration-dry-run.sql
```
- Review generated SQL in CI output before merging — add this as a required PR check
- Migration steps in deployment order:
  1. Back up production database before any migration
  2. Run `prisma migrate deploy` against staging — verify it completes without errors
  3. Only after staging migration succeeds, proceed to production migration
  4. Run `prisma migrate deploy` against production
  5. Verify health check passes after migration before considering deployment complete
- If a migration fails on production:
  1. Do not retry automatically
  2. Halt deployment immediately
  3. Assess whether data was affected
  4. Restore from backup if data integrity is compromised
  5. Fix migration and redeploy through staging first
- Never run `prisma db push` in any environment — always use `prisma migrate deploy`
- Every migration that affects existing data must be reviewed by a developer before merging — flag these explicitly in the PR description

## Database backups
- Production database is backed up automatically before every deployment
- Backup stored in Hetzner Object Storage with 30 day retention
- Staging backup is optional but recommended before major schema changes
- Never run production migrations without a verified backup

## Deployment workflow
Steps in order for both staging and production:
1. CI must pass fully — never deploy if any CI step fails
2. Build Docker image tagged with Git SHA
3. Scan image with Trivy — halt if CRITICAL vulnerabilities found
4. Push image to ghcr.io
5. SSH into target VPS
6. Create Docker Swarm secrets for this SHA from GitHub Actions secrets
7. Run Prisma migration dry run — verify SQL output
8. Back up database (production only — mandatory, staging optional)
9. Run `prisma migrate deploy` against target environment database
10. Deploy stack: `docker stack deploy -c docker-stack.yml {app-name}`
11. Swarm starts new container, runs health check, then stops old container
12. Verify deployment: check service replicas are running and healthy
13. Delete old Swarm secrets from previous SHA
14. If any step fails — pause, alert, old container continues serving traffic

## Rollback
- Because `failure_action: pause` is set, a failed deployment leaves the old container running
- Manual rollback: `docker service update --rollback {service-name}`
- After rollback, investigate failure before retrying deployment
- Never retry a failed deployment without understanding why it failed
- If migration caused data issues — restore from backup, do not attempt rollback via code

## Notifications
- GitHub Actions notifies on deployment success and failure
- Failure notification includes: which step failed, link to logs, whether old container is still running
- Notification channel configured per project at project start

## What you must never do
- Never deploy to production without going through staging first
- Never merge directly to `main` or `staging` without a PR
- Never skip CI checks to speed up a merge
- Never include secrets or `.env` files in Docker images
- Never run production migrations without a database backup
- Never force push to `main` or `staging`
- Never share secrets between staging and production environments
- Never delete Swarm secrets before confirming the new container is healthy
- Never use plain environment variables for sensitive values — always use Swarm secrets
- Never expose Docker, Redis, or database ports publicly on the VPS
- Never use password-based SSH authentication on any VPS
- Never deploy a Docker image with CRITICAL vulnerabilities
- Never run migrations without a dry run review in CI first
- Never expose app container ports directly to host — always route through Caddy
- Never delete the Caddy certificate volume