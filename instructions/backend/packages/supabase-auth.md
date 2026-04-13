# Supabase Auth Rules

## How it works
- Supabase handles all authentication — never implement custom auth logic in NestJS
- Supabase issues JWTs on login — NestJS validates them on every protected request
- Authorization (what a user can do) is enforced at two levels:
  - NestJS guards — role checks before hitting the service
  - Supabase RLS policies — data-level enforcement in PostgreSQL
- Both layers must be consistent — RLS is the safety net, NestJS guards are the first line

## Project start checklist
At the start of every project, ask:
1. Is this app multi-tenant? (users belong to an organization/workspace)
2. What roles exist in this project?
3. Do any roles need permission-based access control beyond role checks?

Answer determines which RLS patterns and guard decorators to implement.

## JWT validation
- Install `@supabase/supabase-js` and `jwks-rsa` or use Supabase's JWT secret directly
- Validate JWT in a global guard: `src/common/guards/supabase-auth.guard.ts`
- Extract and verify the token from the `Authorization: Bearer <token>` header
- On valid token, attach the decoded user to the request object:
```typescript
  request.user = {
    id: payload.sub,
    email: payload.email,
    role: payload.user_metadata?.role ?? 'user',
  }
```
- On invalid or missing token, throw `UnauthorizedException` immediately
- Never trust any user data from the request body for identity — always use the JWT payload

## Guards
- `SupabaseAuthGuard` is registered globally in `app.module.ts` — all routes are protected by default
- Mark public routes explicitly with a `@Public()` decorator:
```typescript
  @Public()
  @Get('health')
  healthCheck() { ... }
```
- Mark role-protected routes with a `@Roles()` decorator:
```typescript
  @Roles('admin')
  @Delete(':id')
  remove(@Param('id') id: string) { ... }
```
- `RolesGuard` runs after `SupabaseAuthGuard` — never assume identity is verified inside `RolesGuard`
- If the project requires permission-based access on top of roles, create a `@Permissions()` decorator and `PermissionsGuard` following the same pattern

## User context
- Always access the current user via a `@CurrentUser()` decorator, never via `request.user` directly in controllers:
```typescript
  @Get('profile')
  getProfile(@CurrentUser() user: AuthUser) { ... }
```
- `AuthUser` is a typed interface defined in `src/common/interfaces/auth-user.interface.ts`
- Never pass the raw JWT or full payload deeper than the controller — pass only the typed `AuthUser`

## Roles
- Roles are stored in Supabase `user_metadata` — set on signup or via Supabase admin API
- Default role for every new user is `user` — never leave role undefined
- Roles available by default: `user`, `admin` — add project-specific roles at project start
- Never hardcode role strings outside of a shared `Role` enum:
```typescript
  export enum Role {
    User = 'user',
    Admin = 'admin',
  }
```
- If permission-based control is needed in future, add a `permissions` array to `user_metadata` without removing roles

## RLS policies
- RLS must be enabled on every table — never disable it
- At project start, ask whether the app is multi-tenant and apply the correct base policies:

  **Single-tenant (users own their own rows):**
```sql
  -- Users can only read their own rows
  CREATE POLICY "users_select_own" ON users
    FOR SELECT USING (auth.uid() = id);
```

  **Multi-tenant (users belong to an organization):**
```sql
  -- Users can only read rows belonging to their organization
  CREATE POLICY "org_select_own" ON resources
    FOR SELECT USING (
      organization_id = (
        SELECT organization_id FROM users WHERE id = auth.uid()
      )
    );
```
- Admin role bypasses RLS using a Supabase service role key — never expose the service role key to the client
- Every new table must have RLS policies defined before it is used — never leave a table without policies
- Document every RLS policy with a comment explaining what it protects and why

## Service role key
- The Supabase service role key bypasses all RLS — treat it as a root password
- Use it only in NestJS backend, never in frontend code
- Store it in `.env` as `SUPABASE_SERVICE_ROLE_KEY` — never commit the actual value
- Use it only for admin operations that legitimately need to bypass RLS (e.g. sending system notifications, admin data exports)
- Every use of the service role key must have a comment explaining why RLS bypass is necessary

## Testing
- In unit and standard e2e tests, mock the JWT validation — do not require a real Supabase connection
- Generate test tokens with a fixed test secret defined in `.env.test`
- RLS policy tests run only against a real Supabase test project when RLS policies change
- Always test: valid token accepted, expired token rejected, missing token rejected, wrong role rejected

## What you must never do
- Never implement custom login, registration, or password reset in NestJS — Supabase handles this
- Never store passwords in your database
- Never expose the service role key outside of the NestJS backend
- Never leave a table without RLS policies
- Never trust user-supplied identity from request body — always use JWT payload
- Never hardcode role strings — always use the `Role` enum