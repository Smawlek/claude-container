# AI Assistant Instructions

## Read this first
You are an AI coding assistant working on a professional software project.
Before doing anything else, read all instruction files listed below in order.
Do not write a single line of code until you have read all of them.

## How to use these instructions
- This file is the entry point — it applies to every project and every task
- Instruction files define rules you must follow at all times
- The mistakes log contains errors that have happened before — you must not repeat them
- Package-specific files apply only when that package is present in the project

## Instruction files — read in this order

### Always read
1. `instructions/base.md` — universal rules for all projects and all tasks
2. `instructions/testing.md` — testing philosophy and rules
3. `context/mistakes-log.md` — past mistakes, read carefully and never repeat them

### Backend projects — read if this is a NestJS project
4. `instructions/backend/nestjs.md` — NestJS structure and patterns
5. `instructions/backend/ci-cd.md` — deployment and CI/CD rules

### Backend packages — read only if the package is present in the project
- `instructions/backend/packages/prisma.md` — if Prisma is installed
- `instructions/backend/packages/supabase-auth.md` — if Supabase Auth is used
- `instructions/backend/packages/swagger.md` — if @nestjs/swagger is installed
- `instructions/backend/packages/redis.md` — if Redis is used
- `instructions/backend/packages/bullmq.md` — if BullMQ is installed
- `instructions/backend/packages/file-uploads.md` — if file uploads are implemented
- `instructions/backend/packages/loki.md` — if Grafana Loki is configured

### Frontend projects — read if this is a frontend project
- `instructions/frontend/` — framework file will be added when frontend framework is decided

## At the start of every project
Before writing any code on a new or existing project, you must:
1. Identify whether this is a backend, frontend, or fullstack project
2. Scan `package.json` to identify which packages are installed
3. Load the relevant instruction files based on what you find
4. Ask the project start checklist questions defined in the relevant instruction files
5. Present a summary of what you have read and what rules apply — wait for confirmation before proceeding

## At the start of every task
1. State clearly what you are about to do
2. List which files you will touch and why
3. Wait for explicit approval before making any changes

## Switching AI models
This file and all instruction files are model-agnostic — they work with any AI coding tool.
When switching tools, rename or symlink this file to match the tool's convention:
- Claude Code: `CLAUDE.md`
- Cursor: `.cursorrules`
- GitHub Copilot: `.github/copilot-instructions.md`
- Aider: `CONVENTIONS.md`
The content never changes — only the filename.