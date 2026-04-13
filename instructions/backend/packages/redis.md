# Redis Rules

## Setup
- Install `@nestjs/cache-manager`, `cache-manager`, `cache-manager-redis-yet`, `ioredis`
- Redis connection is configured once in `app.module.ts` via `CacheModule.registerAsync()`
- Connection config comes from environment variables — never hardcode connection details:
- Add all Redis env vars to `.env.example` immediately on setup
- Redis runs self-hosted on Hetzner VPS — define it in `docker-compose.yml` for local dev

## Connection
- Use a single shared `ioredis` connection instance for all Redis operations
- Configure connection retry strategy — never let connection failures crash the app silently:
```typescript
  retryStrategy: (times) => Math.min(times * 50, 2000)
```
- Always handle Redis connection errors in logs — if Redis is down, the app must degrade gracefully, not crash
- BullMQ uses the same Redis instance — connection config is shared via a provider

## Caching
- Use `@nestjs/cache-manager` for all caching — never interact with Redis directly for cache operations
- Cache keys must be namespaced by feature: `users:findById:${id}`, `products:findAll`
- Always set explicit TTL per cache entry — never rely on the global default alone
- Default TTL comes from `REDIS_TTL_SECONDS` env var — override per use case where needed
- Cache invalidation must happen in the same service method that mutates the data:
```typescript
  async update(id: string, dto: UpdateUserDto): Promise<UserResponseDto> {
    const result = await this.usersRepository.update(id, dto)
    await this.cacheManager.del(`users:findById:${id}`)
    return result
  }
```
- Never cache sensitive data: passwords, tokens, personal data unless explicitly required and justified

## Session storage
- Sessions are stored in Redis with key pattern: `sessions:${userId}:${sessionId}`
- Always set explicit session TTL — default to 24 hours unless project requires otherwise
- On logout, explicitly delete the session key from Redis — never rely on TTL expiry alone
- On password change or account disable, invalidate all active sessions for that user immediately

## Key naming conventions
- All keys follow pattern: `{feature}:{operation}:{identifier}`
- Examples:
  - `users:findById:uuid`
  - `sessions:userId:sessionId`
  - `rate-limit:ip:127.0.0.1`
- Never use spaces or special characters in keys
- Document any key pattern that deviates from the convention with a comment

## Graceful degradation
- If Redis is unavailable, the app must continue functioning without cache — log the error and proceed
- Never make Redis a hard dependency for core business logic
- Cache misses are not errors — always fall through to the database on a miss

## Local development
- Redis runs in Docker — defined in `docker-compose.yml`:
```yaml
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    command: redis-server --appendonly yes
```
- Never connect local dev to production Redis instance

## Security
- Always set a strong Redis password in production via `REDIS_PASSWORD`
- Redis must not be publicly accessible — bind to localhost or internal VPS network only
- Never log Redis keys that contain sensitive data

## What you must never do
- Never hardcode Redis connection details — always use environment variables
- Never cache sensitive data without explicit justification
- Never skip cache invalidation after a mutation
- Never make Redis a hard dependency — always degrade gracefully if unavailable
- Never expose Redis port publicly on the VPS
- Never use the same Redis instance for production and staging