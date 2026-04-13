# Grafana Loki + Pino Logging Rules

## Setup
- Install `nestjs-pino`, `pino-http`, `pino-loki`
- Replace NestJS default logger with `nestjs-pino` globally in `main.ts`
- Loki connection config comes from environment variables — never hardcode:
- Add all Loki env vars to `.env.example` immediately on setup
- Loki runs self-hosted on Hetzner VPS — define it in `docker-compose.yml` for local dev

## Bootstrap configuration
- Configure `nestjs-pino` in `main.ts` with Loki transport:
```typescript
  app = await NestFactory.create(AppModule, {
    bufferLogs: true,
  })
  app.useLogger(app.get(Logger))
```
- `LoggerModule` is registered globally in `app.module.ts` with `forRoot()`:
```typescript
  LoggerModule.forRootAsync({
    useFactory: (config: ConfigService) => ({
      pinoHttp: {
        level: config.get('APP_ENV') === 'production' ? 'info' : 'debug',
        transport: {
          targets: [
            {
              target: 'pino-loki',
              options: {
                host: config.get('LOKI_HOST'),
                basicAuth: {
                  username: config.get('LOKI_USERNAME'),
                  password: config.get('LOKI_PASSWORD'),
                },
                labels: {
                  app: config.get('APP_NAME'),
                  env: config.get('APP_ENV'),
                },
                batching: true,
                interval: 5,
              },
            },
            // Always keep console output for local dev
            ...(config.get('APP_ENV') !== 'production'
              ? [{ target: 'pino-pretty', options: { colorize: true } }]
              : []),
          ],
        },
        redact: [
          'req.headers.authorization',
          'req.body.password',
          'req.body.token',
        ],
      },
    }),
    inject: [ConfigService],
  })
```

## Usage
- Inject logger per class using `@InjectPinoLogger()`:
```typescript
  @Injectable()
  export class UsersService {
    constructor(
      @InjectPinoLogger(UsersService.name)
      private readonly logger: PinoLogger,
    ) {}
  }
```
- Never use `console.log` — always use the injected logger
- Never use NestJS default `Logger` class after `nestjs-pino` is set up

## Log levels
- `debug` — detailed flow information, local dev only, never in production
- `info` — normal operations: service started, job completed, user action performed
- `warn` — unexpected but handled situations: cache miss on critical path, retry attempt
- `error` — failures that need attention: job failed all retries, external service down
- Production log level is `info` — debug logs are stripped automatically

## What to log
- Service entry points for significant operations: `info`
- All errors with full context: `error`
- Retry attempts in BullMQ processors: `warn`
- External API calls (start and completion): `info`
- Cache misses on critical paths: `warn`
- App bootstrap completion: `info`

## What never to log
- Passwords, tokens, API keys, secrets
- Full request bodies on auth endpoints
- Personal data (emails, names, addresses) unless explicitly required and justified
- Raw Prisma errors with internal query details — sanitize before logging
- Excessive debug logs in hot paths — impacts performance

## Structured logging
- Always log as structured objects, never as concatenated strings:
```typescript
  // Wrong
  this.logger.error(`Failed to process job ${jobId} for user ${userId}`)

  // Correct
  this.logger.error({ jobId, userId, error: error.message }, 'Job processing failed')
```
- Always include relevant context fields: `userId`, `jobId`, `feature`, `method`
- Error logs must always include `error.message` — never log raw error objects

## Loki labels
- Labels are set globally at app level — never add high-cardinality labels (user IDs, request IDs) as Loki labels
- Standard labels for every app:
  - `app` — application name from `APP_NAME`
  - `env` — environment from `APP_ENV`
- High-cardinality values (userId, requestId) go in log fields, not labels

## Local development
- Loki runs in Docker alongside Grafana for local log viewing:
```yaml
  loki:
    image: grafana/loki:latest
    ports:
      - "3100:3100"
    volumes:
      - loki_data:/loki

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    environment:
      GF_SECURITY_ADMIN_PASSWORD: admin
    volumes:
      - grafana_data:/var/lib/grafana
```
- `pino-pretty` is enabled locally for readable console output alongside Loki
- Never disable Loki transport in production — always ship logs to Loki

## Graceful degradation
- If Loki is unavailable, logs must still appear in console — never lose logs because Loki is down
- `pino-loki` batches logs — if Loki is unreachable, logs are buffered and retried automatically
- Always monitor Loki availability — alert if logs stop arriving

## What you must never do
- Never use `console.log` anywhere in the codebase
- Never log sensitive data — passwords, tokens, personal data
- Never add user IDs or request IDs as Loki labels — use log fields instead
- Never disable logging in production to improve performance
- Never log raw error objects — always extract and sanitize the message
- Never concatenate log strings — always use structured objects