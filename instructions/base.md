# Base Rules

## Before starting any task
- Read all instruction files and the mistakes log before doing anything
- If the task is ambiguous, ask clarifying questions — do not assume intent
- If the task is too large or has unclear steps, break it into smaller subtasks, present the full execution plan, and wait for approval before starting any of them
- Present your plan (which files you will touch and why) and wait for explicit approval before writing any code

## Making changes
- Ask for approval before every change, no exceptions
- Never modify more than what was explicitly asked
- Deletion is allowed — but you must explain what you deleted and why before doing it
- After changes are approved, ask which GitHub branch to push to

## After completing a task
- Summarize what changed, in which file, and why
- Update CHANGELOG.md using this format:
- Update relevant documentation if the change affects behavior, API, or configuration

## Testing
- After every task, ask whether to write or update tests
- When writing tests, cover: happy path, edge cases, error cases, and full user journeys where applicable
- Aim for high code coverage — surface any untested paths explicitly
- Detailed testing rules are defined in testing.md

## Code style
- Write code a normal, experienced developer would write — no over-engineering
- Readability over cleverness, always
- Follow patterns already present in the codebase — check existing files before inventing structure
- No abbreviations in variable or function names
- No magic numbers — use named constants

## Naming
- Names should be self-explanatory — a reader should understand what something does without reading its body
- Use full descriptive names: `getUserByEmail` not `getUser`, `isEmailVerified` not `verified`

## Comments
- Every function must have a JSDoc comment: description, @param, @returns, @throws if applicable
- Do not add comments that just restate the code — comments explain why, not what
- Complex logic that isn't obvious must have an inline explanation above it

## TypeScript
- Strict TypeScript only — no `any`, no `as` casts unless absolutely unavoidable
- If `any` or a cast is used, add a comment explaining why
- Every function must have explicit parameter types and return type declared

## Linting
- Follow ESLint and any other linter rules defined in the project
- Never disable a linter rule — if one blocks you, surface it and wait for a decision
- If no linter config exists, ask before proceeding — do not create one without instruction

## New projects
- Every new project must be initialized with ESLint and Prettier before writing any code
- Ask which additional linters or tools are needed before initializing

## Environment variables
- Every new env variable must be added to `.env.example` immediately with a placeholder value and a comment explaining what it is
- If `.env.example` does not exist, create it
- Never hardcode values that belong in environment variables

## What you must never do
- Never install new packages without asking first
- Never change configuration files (tsconfig, eslint, docker, .env) without explicit instruction
- Never generate placeholder or dummy code (TODO stubs, lorem ipsum, fake data in production paths)
- Never make assumptions about business logic — ask
- Never commit `.env` to version control under any circumstances — always use `.env.example` with placeholder values only