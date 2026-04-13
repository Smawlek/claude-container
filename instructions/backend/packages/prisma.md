# Prisma Rules

## Setup
- Prisma client is initialized once in `src/common/prisma/prisma.service.ts` and injected via `PrismaModule`
- `PrismaModule` is global — import it once in `app.module.ts`, never import it per feature module
- Always run `prisma generate` after any schema change before writing code that uses new models
- Never import `PrismaClient` directly outside of `prisma.service.ts`

## Schema conventions
- All column names use `snake_case` — map to camelCase in Prisma using `@map`
- All table names use `snake_case` plural — map using `@@map`
- Every model must have:
  - `id` as UUID primary key: `id String @id @default(uuid())`
  - `created_at DateTime @default(now()) @map("created_at")`
  - `updated_at DateTime @updatedAt @map("updated_at")`
  - `deleted_at DateTime? @map("deleted_at")`
- Add `enabled Boolean @default(true)` only where toggling makes sense — document why in a schema comment
- Example model:
```prisma
  model User {
    id         String    @id @default(uuid())
    email      String    @unique
    enabled    Boolean   @default(true)
    deleted_at DateTime? @map("deleted_at")
    created_at DateTime  @default(now()) @map("created_at")
    updated_at DateTime  @updatedAt @map("updated_at")

    @@map("users")
  }
```

## Soft deletes
- Never use Prisma's `delete()` or `deleteMany()` — always soft delete by setting `deleted_at`
- All queries must filter out soft deleted records by default: `where: { deleted_at: null }`
- If a query intentionally includes deleted records, add a comment explaining why
- `deleted_at` timestamp = when the record was soft deleted — its meaning beyond that is implementation-specific and must be documented in the schema

## Migrations
- Never edit migration files after they are created — create a new migration instead
- Always review the generated migration SQL before applying it
- Migration names must be descriptive: `add_enabled_to_users` not `update1`
- Never run migrations directly against production — always through CI/CD pipeline
- Keep a backup before running migrations on production

## Schema changes that affect existing data
- Before making any schema change that would modify, move, or lose existing data — stop completely
- Present to the developer:
  - What data would be affected and how much
  - What options are available and their tradeoffs
  - What the risks are for each option
  - Whether the change is reversible
- Never proceed until the developer explicitly approves the approach
- Once approved, implement exactly what was decided and document it:
  - Add a comment inside the migration file explaining what the change does and why
  - Add an entry to `CHANGELOG.md` describing the data impact
- Never assume a safe default — data migrations are high-risk and context-specific

## Querying
- All Prisma calls live in repositories — never call Prisma from services or controllers
- Never use `findFirst` when you mean `findUnique` — use the most specific method available
- Always select only the fields you need — never return entire models when a subset suffices:
```typescript
  // Wrong
  return this.prisma.user.findUnique({ where: { id } })

  // Correct
  return this.prisma.user.findUnique({
    where: { id },
    select: { id: true, email: true, enabled: true }
  })
```
- For paginated queries always include `skip`, `take`, and `orderBy`
- Never use raw SQL unless Prisma cannot express the query — if used, document why

## Error handling
- Wrap all Prisma calls in try/catch in the repository
- Map Prisma errors to NestJS exceptions:
  - `P2002` (unique constraint) → `ConflictException`
  - `P2025` (record not found) → `NotFoundException`
  - All others → `InternalServerErrorException` with logged details
- Never let Prisma error codes surface to the client

## Transactions
- Use `prisma.$transaction()` whenever multiple writes must succeed or fail together
- Never perform dependent writes outside of a transaction
- Keep transactions short — no external API calls inside a transaction

## Performance
- Always add indexes for columns used in `where` clauses — define in schema with `@@index`
- Never load relations unless explicitly needed — no eager loading by default
- For large datasets use cursor-based pagination, not offset-based

## What you must never do
- Never call `prisma.delete()` — always soft delete via `deleted_at`
- Never run `prisma db push` in production — always use `prisma migrate deploy`
- Never expose raw Prisma types outside repositories — always map to typed interfaces
- Never proceed with a data-affecting schema change without explicit developer approval