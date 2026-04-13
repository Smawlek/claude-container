# Swagger / OpenAPI Rules

## Setup
- Install `@nestjs/swagger` and `swagger-ui-express`
- Initialize Swagger in `main.ts` — never in a module or controller
- Swagger UI is available at `/api/docs` in development only — never expose it in production
- Use environment variable `SWAGGER_ENABLED=true/false` to control visibility:
```typescript
  if (process.env.SWAGGER_ENABLED === 'true') {
    const config = new DocumentBuilder()
      .setTitle(process.env.APP_NAME)
      .setDescription(process.env.APP_DESCRIPTION)
      .setVersion(process.env.API_VERSION)
      .addBearerAuth()
      .build()
    const document = SwaggerModule.createDocument(app, config)
    SwaggerModule.setup('api/docs', app, document)
  }
```
- Add `SWAGGER_ENABLED`, `APP_NAME`, `APP_DESCRIPTION` to `.env.example` immediately

## Controllers
- Every controller must have `@ApiTags('feature-name')` — groups endpoints in Swagger UI
- Every endpoint must have:
  - `@ApiOperation({ summary: '...' })` — one line description of what the endpoint does
  - `@ApiResponse` for every possible response status code — success and errors
  - `@ApiBearerAuth()` on every protected endpoint
- Example:
```typescript
  @ApiTags('users')
  @Controller('users')
  export class UsersController {
    @Get(':id')
    @ApiBearerAuth()
    @ApiOperation({ summary: 'Get user by ID' })
    @ApiResponse({ status: 200, description: 'User found', type: UserResponseDto })
    @ApiResponse({ status: 401, description: 'Unauthorized' })
    @ApiResponse({ status: 404, description: 'User not found' })
    findOne(@Param('id') id: string) { ... }
  }
```

## DTOs
- Every DTO property must have `@ApiProperty()` with description and example:
```typescript
  @ApiProperty({ description: 'User email address', example: 'user@example.com' })
  @IsEmail()
  readonly email: string
```
- Optional properties use `@ApiPropertyOptional()` instead of `@ApiProperty({ required: false })`
- Never leave a DTO property without an `@ApiProperty` decorator — undocumented fields cause confusion

## Response DTOs
- Every endpoint must return a typed response DTO — never return plain objects or Prisma types
- Response DTOs live in `dto/` alongside request DTOs: `user-response.dto.ts`
- Response DTOs must reflect the full response envelope shape:
```typescript
  @ApiProperty({ example: true })
  success: boolean

  @ApiProperty({ type: UserDto })
  data: UserDto | null

  @ApiProperty({ example: {} })
  meta: Record<string, unknown>

  @ApiProperty({ example: null })
  error: string | null

  @ApiProperty({ example: '2026.04.13' })
  apiVersion: string
```

## Keeping docs accurate
- Swagger decorators must be updated in the same commit as the endpoint change — never let them fall out of sync
- If an endpoint is deprecated, mark it with `@ApiOperation({ deprecated: true })` — never silently remove it
- When adding a new error case to a service, add the corresponding `@ApiResponse` to the controller immediately

## What you must never do
- Never expose Swagger UI in production — always guard with `SWAGGER_ENABLED`
- Never leave an endpoint without `@ApiOperation` and `@ApiResponse` decorators
- Never leave a DTO property without `@ApiProperty`
- Never return undocumented response shapes — always use typed response DTOs
- Never let Swagger decorators fall out of sync with actual endpoint behavior