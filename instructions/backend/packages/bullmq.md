# BullMQ Rules

## Setup
- Install `@nestjs/bullmq`, `bullmq`, `@bull-board/api`, `@bull-board/nestjs`, `@bull-board/express`
- BullMQ uses the same Redis instance as caching and sessions — reuse the shared ioredis connection
- Every queue is defined as a named constant in `src/common/constants/queues.constant.ts`:
```typescript
## Structure
- Each queue has its own module under `src/[feature]/[feature]-queue.module.ts`
- Every queue requires three files:
  - `[feature].producer.ts` — adds jobs to the queue
  - `[feature].processor.ts` — processes jobs from the queue
  - `[feature]-queue.module.ts` — registers producer and processor
- Producers are injected into services — services never interact with BullMQ directly
- Processors contain only job processing logic — no business logic, delegate to services

## Job definition
- Every job payload must be a typed interface:
```typescript
  export interface SendEmailJob {
    to: string
    subject: string
    templateId: string
    variables: Record<string, string>
  }
```
- Never pass untyped or raw objects as job payloads
- Job names must be descriptive constants defined alongside the queue constant:
```typescript
  export const EMAIL_JOBS = {
    SEND_WELCOME: 'send-welcome',
    SEND_PASSWORD_RESET: 'send-password-reset',
  } as const
```

## Job configuration
- Always set explicit job options — never rely on BullMQ defaults:
```typescript
  await this.emailQueue.add(EMAIL_JOBS.SEND_WELCOME, payload, {
    attempts: 3,
    backoff: { type: 'exponential', delay: 5000 },
    removeOnComplete: 100,   // keep last 100 completed jobs
    removeOnFail: 500,       // keep last 500 failed jobs
  })
```
- Default retry strategy: 3 attempts with exponential backoff starting at 5 seconds
- Sensitive jobs (payments, notifications) may need more attempts — document why if changed
- Always set `removeOnComplete` and `removeOnFail` — never let completed jobs accumulate indefinitely

## Processors
- Every processor must extend `WorkerHost` and implement `process()`
- Always handle errors explicitly in the processor — never let unhandled errors silently fail:
```typescript
  async process(job: Job<SendEmailJob>): Promise<void> {
    try {
      await this.emailService.send(job.data)
    } catch (error) {
      this.logger.error({
        message: 'Email job failed',
        jobId: job.id,
        attempt: job.attemptsMade,
        error: error.message,
      })
      throw error // rethrow so BullMQ handles retry
    }
  }
```
- Always rethrow errors after logging — BullMQ needs the throw to trigger retries
- Never put sensitive data in job logs — sanitize before logging

## Scheduled / recurring jobs
- Recurring jobs use cron expressions defined as named constants — never inline cron strings
- Register recurring jobs on app bootstrap in a dedicated `SchedulerService`
- Always check if a recurring job already exists before adding it — prevent duplicates on restart:
```typescript
  const existing = await this.scheduledQueue.getRepeatableJobs()
  if (!existing.find(j => j.name === SCHEDULED_JOBS.DAILY_REPORT)) {
    await this.scheduledQueue.add(SCHEDULED_JOBS.DAILY_REPORT, {}, {
      repeat: { cron: CRON.DAILY_MIDNIGHT },
    })
  }
```

## Bull Board
- Bull Board is mounted at `BULL_BOARD_PATH` (default `/api/queues`) in `main.ts`
- Always protect Bull Board with HTTP Basic Auth using `BULL_BOARD_USERNAME` and `BULL_BOARD_PASSWORD`
- Never expose Bull Board without authentication — it shows all job data including payloads
- Bull Board is enabled in all environments — use strong credentials in production
- Register every queue with Bull Board on setup — never leave a queue unmonitored

## Graceful shutdown
- Always register a shutdown hook to let active jobs finish before the app stops:
```typescript
  app.enableShutdownHooks()
```
- Never kill the app mid-job — always wait for the current job to complete or timeout

## What you must never do
- Never hardcode queue name strings — always use constants
- Never pass untyped payloads to jobs
- Never put business logic in processors — delegate to services
- Never swallow errors in processors — always rethrow after logging
- Never expose Bull Board without authentication
- Never let completed jobs accumulate indefinitely — always set `removeOnComplete` and `removeOnFail`
- Never add a recurring job without checking for duplicates first