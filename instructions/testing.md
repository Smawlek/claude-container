# Testing Rules

## Framework
- Unit tests: Jest
- e2e tests: Jest + Supertest against the actual NestJS app
- Both are configured in `package.json` with separate configs: `jest` for unit, `jest-e2e` for e2e

## When to write tests
- After every task, the AI asks whether to write or update tests — never writes them without asking
- When tests are requested, cover all of the following:
  - Happy path
  - Edge cases (empty arrays, zero values, boundary values)
  - Error cases (invalid input, not found, forbidden)
  - Full user journeys for e2e tests

## Coverage
- Minimum 80% coverage enforced in CI — PRs below this threshold are blocked
- Exclude from coverage: DTOs, constants, generated files, `main.ts`, `*.module.ts`
- Never write tests just to hit 80% — coverage is a byproduct of good tests, not the goal
- After writing tests, explicitly report which paths are untested and why

## Unit tests
- One spec file per service: `[feature].service.spec.ts` lives next to the service
- Test behavior, not implementation — never test that a specific function was called internally
- Mock all dependencies (repositories, external services) — unit tests never touch the database
- Each test must be independent — no shared state between tests
- Use `beforeEach` to reset mocks and reinitialize the subject under test
- Name tests clearly:
## Repository tests
- Repositories are tested against a local Docker PostgreSQL instance — never against production or staging
- Test all query methods: findById, findAll, create, update, delete
- Test that Prisma errors are caught and rethrown as NestJS exceptions

## e2e tests
- One e2e spec file per feature: `[feature].e2e-spec.ts` lives in `test/`
- e2e tests run against a real NestJS app instance with local Docker PostgreSQL
- Always seed required data in `beforeEach` and clean up in `afterEach`
- Test the full HTTP cycle: request → guard → controller → service → repository → response envelope
- Always assert the full response envelope shape:
```typescript
  expect(response.body).toMatchObject({
    success: true,
    data: expect.objectContaining({ ... }),
    meta: expect.any(Object),
    error: null,
    apiVersion: expect.any(String),
  })
```
- Test authentication: protected routes must return 401 without a valid token
- Test authorization: users must not access resources they don't own (403)

## Supabase-specific testing
- RLS policies and Supabase Auth are not tested on every run
- Run RLS and Auth integration tests only when RLS policies or auth logic change
- These tests run against a dedicated Supabase test project — never against production
- Mock Supabase JWT tokens in all other tests — do not require a real Supabase connection for unit or standard e2e tests

## Test database
- Local PostgreSQL runs in Docker — defined in `docker-compose.test.yml`
- Prisma migrations run automatically before the test suite starts
- Test database is wiped and reseeded on every full test run
- Never reuse test data between test runs — always start from a clean state

## Mocking
- Use Jest's built-in mocking — no additional mocking libraries
- Mock at the module level using `jest.fn()` and `jest.spyOn()`
- Never mock the subject under test itself
- Repository mocks must return typed data matching the actual return types

## What you must never do
- Never test against production or staging database
- Never write tests that depend on order of execution
- Never mock the module you are testing
- Never assert implementation details — assert inputs and outputs only
- Never skip `afterEach` cleanup in e2e tests — always leave the database clean
- Never write tests solely to increase coverage numbers