# File Uploads Rules

## Setup
- Install `@nestjs/platform-express`, `multer`, `@aws-sdk/client-s3`, `@aws-sdk/s3-request-presigner`
- Install `sharp` only if image processing is required — ask at project start
- S3 client is initialized once in `src/common/storage/storage.service.ts`
- Storage service is global — import once in `app.module.ts`
- Add all storage env vars to `.env.example` immediately on setup:
## Project start checklist
At the start of every project that uses file uploads, ask:
1. What file types are allowed? (images, documents, any)
2. Is image processing needed? (resizing, optimization, thumbnail generation)
3. Are files public or private? (public CDN URL vs signed URLs)
4. Should old files be deleted when replaced?

Answers determine validation rules, processing pipeline, and access control setup.

## Structure
- All storage logic lives in `src/common/storage/storage.service.ts`
- Feature services call `StorageService` — never use S3 client directly outside of `StorageService`
- File upload endpoints live in their feature module — never create a generic global upload endpoint
- Multer is configured per endpoint — never use global Multer config

## File validation
- Always validate before uploading to S3 — never store invalid files:
  - File size: enforce `MAX_FILE_SIZE_BYTES` from env
  - MIME type: validate against an explicit allowlist defined at project start
  - File extension: validate against the same allowlist — never trust extension alone
  - Magic bytes: validate actual file content matches declared MIME type
- Reject files that fail any validation with `BadRequestException` before they reach S3
- Never rely on the client-provided filename or MIME type alone

## File naming
- Never store files with their original filename — always generate a UUID-based key:
```typescript
  const key = `${folder}/${uuid()}.${extension}`
```
- Folder structure in bucket: `{feature}/{userId}/{uuid}.{ext}`
  - Example: `avatars/user-uuid/file-uuid.jpg`
- Never expose the internal S3 key to the client directly — return a URL or signed URL only

## Access control
- **Public files** (avatars, public assets): store in a public bucket folder, return direct CDN URL
- **Private files** (documents, user data): generate presigned URLs with short expiry (15 minutes default)
- Never generate presigned URLs without verifying the requesting user owns the file
- Presigned URL expiry must come from env var: `PRESIGNED_URL_EXPIRY_SECONDS=900`

## Image processing
- Use `sharp` for all image operations — never use other image libraries
- Image processing runs as a BullMQ job — never block the request thread with processing
- Always process images before storing to S3 — never store unprocessed originals unless explicitly required
- Standard operations when image processing is enabled:
  - Strip EXIF metadata (privacy — removes location data)
  - Convert to WebP for web images unless another format is explicitly required
  - Resize to maximum dimensions defined at project start
  - Generate thumbnails as separate S3 objects if needed

## Replacing files
- When a file is replaced, ask at project start whether to delete the old file
- If yes: always delete the old S3 object in the same operation as the upload
- Never leave orphaned files in S3 — track file keys in the database

## Database
- Always store file metadata in the database alongside the S3 key:
```typescript
  // Minimum fields on any file record
  s3_key: string        // internal S3 object key
  mime_type: string     // validated MIME type
  size_bytes: number    // file size in bytes
  uploaded_by: string   // user UUID
  created_at: DateTime
  deleted_at: DateTime? // soft delete — never hard delete file records
```
- Soft delete file records — never hard delete even if the S3 object is removed

## Error handling
- If S3 upload fails, never save the file record to the database
- If database save fails after S3 upload, delete the S3 object immediately to avoid orphans
- Wrap upload + database save in a try/catch — log full context on failure
- Never return S3 error details to the client

## Local development
- Use a local MinIO instance in Docker as S3-compatible storage — never connect local dev to production bucket:
```yaml
  minio:
    image: minio/minio
    ports:
      - "9000:9000"
      - "9001:9001"
    environment:
      MINIO_ROOT_USER: minioadmin
      MINIO_ROOT_PASSWORD: minioadmin
    command: server /data --console-address ":9001"
    volumes:
      - minio_data:/data
```
- MinIO uses the same S3 SDK — only the endpoint changes via env var

## What you must never do
- Never store files with original client-provided filenames
- Never skip file validation before uploading
- Never expose internal S3 keys to the client
- Never generate presigned URLs without ownership verification
- Never block the request thread with image processing — always use BullMQ
- Never leave orphaned S3 objects — always track keys in the database
- Never hard delete file records from the database
- Never connect local development to the production S3 bucket