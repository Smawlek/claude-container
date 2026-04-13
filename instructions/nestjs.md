# NestJS Rules

## Project structure
- Feature-based module structure — one folder per feature under `src/`
- Every feature folder contains: module, controller, service, repository, dto/, and spec files
- Shared code (guards, decorators, interceptors, pipes) lives in `src/common/`
- Configuration lives in `src/config/` using `@nestjs/config` with validation via `zod`
- Entry point is always `src/main.ts` — do not add logic here beyond bootstrapping
## Modules
- Every feature must have its own module
- After creating any injectable (service, repository, guard), immediately register it in its module
- Never use global modules except for truly global concerns (config, logging)
- Import only what the module needs — no barrel imports that pull in the entire app

## Controllers
- Controllers handle HTTP only — no business logic
- Validate all incoming data using DTOs with `class-validator` decorators
- Always define explicit response types and HTTP status codes
- Every endpoint must have Swagger decorators (`@ApiOperation`, `@ApiResponse`, `@ApiBearerAuth`)
- All routes are prefixed with `/api` — never expose routes without this prefix

## Services
- All business logic lives in services
- Services never call Prisma directly — always go through the repository
- One service per feature — do not cross-call services unless absolutely necessary, explain why if you do
- If a service method can fail, throw a typed NestJS exception (`NotFoundException`, `ForbiddenException`, etc.) — never return null to signal failure

## Repositories
- Repositories are the only place Prisma is called
- One repository per feature, injected into its service
- Repository methods must be named clearly: `findById`, `findAllByUserId`, `create`, `update`, `delete`
- Never expose raw Prisma types outside the repository — return mapped plain objects or typed interfaces
- Never let Prisma errors bubble up to the service — catch and rethrow as NestJS exceptions here

## DTOs
- Every incoming request body and query param must have a DTO
- Use `class-validator` for validation and `class-transformer` for transformation
- Use `@IsUUID()`, `@IsEmail()`, `@IsString()`, `@IsOptional()` etc. — never trust raw input
- DTOs are immutable — use `readonly` on all properties

## Response envelope
- Every API response must use this exact shape:
```typescript
  {
    success: boolean        // true on 2xx, false on error
    data: T | null          // response payload, null on error
    meta: Record<string, unknown>  // always present, empty object {} if nothing to add
    error: string | null    // human-readable error message, null on success
    apiVersion: string      // release date in YYYY.MM.DD format from env
  }
```
- Implement as a global interceptor in `src/common/interceptors/response.interceptor.ts`
- Never return raw data directly from a controller — always goes through the interceptor
- Never remove or rename existing response fields — only add new ones to avoid breaking Frontend
- Breaking changes must be documented in CHANGELOG.md with the release date

## Error handling
- Use NestJS built-in exceptions for all expected errors
- Create custom exceptions in `src/common/exceptions/` only when built-in ones are insufficient
- Global exception filter must be registered in `main.ts` to format all errors into the response envelope
- Never expose internal error details or stack traces to the client

## Validation pipe
- `ValidationPipe` must be registered globally in `main.ts` with these options:
```typescript
  new ValidationPipe({
    whitelist: true,
    forbidNonWhitelisted: true,
    transform: true,
  })
```

## Rate limiting
- Use `@nestjs/throttler` registered globally
- Default limits: 100 requests per 60 seconds per IP
- Sensitive endpoints (auth, password reset) must have stricter limits defined explicitly
- Never remove rate limiting from a route without explicit instruction

## ESLint + Prettier (required on every new project)
- Install: `@typescript-eslint/parser`, `@typescript-eslint/eslint-plugin`, `eslint-config-prettier`, `prettier`
- Rules that must always be enabled:
  - `@typescript-eslint/no-explicit-any: error`
  - `@typescript-eslint/explicit-function-return-type: error`
  - `@typescript-eslint/no-unused-vars: error`
  - `@typescript-eslint/explicit-module-boundary-types: error`
  - `no-console: error` (use structured logger instead)
- Prettier config: single quotes, 2 space indent, trailing commas, 100 char line length
- Both must pass with zero errors before any commit

## Logging
- Never use `console.log` — use a structured logger (Pino via `nestjs-pino`) that outputs JSON
- Logger must support external log aggregation (e.g. Grafana Loki) — detailed setup in `packages/loki.md`
- Inject logger per class using `@InjectPinoLogger(ClassName.name)`
- Log at the service level, not controller level
- Log errors with full context: method name, sanitized input params, error message
- Never log sensitive data: passwords, tokens, personal data

## Security
- Never expose internal error details to the client
- All routes are protected by Supabase JWT guard by default
- Explicitly mark public routes with a `@Public()` decorator
- Supabase JWT validation and RLS rules are defined in `packages/supabase-auth.md`

## What you must never do
- Never put business logic in a controller
- Never call Prisma outside of a repository
- Never return raw database objects from a controller — always map to a response DTO
- Never create a module without registering it in `app.module.ts`
- Never use `console.log` — always use the structured logger
- Never disable ESLint rules or skip validation pipe