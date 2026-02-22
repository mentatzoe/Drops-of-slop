---
description: REST and API route design conventions
paths:
  - "src/api/**/*"
  - "**/routes/**/*"
---

# API Design

## Route Conventions
- Use plural nouns for resource collections: `/users`, `/posts`, `/comments`
- Use HTTP methods semantically: GET reads, POST creates, PUT replaces, PATCH updates, DELETE removes
- Return appropriate status codes: 200 OK, 201 Created, 204 No Content, 400 Bad Request, 404 Not Found

## Request/Response
- Validate request bodies with a schema (Zod, Joi, or equivalent) at the handler entry
- Return consistent envelope: `{ data, error, meta }` for all endpoints
- Include pagination metadata for list endpoints: `{ page, limit, total, hasMore }`

## Error Handling
- Return structured error objects: `{ code, message, details }`
- Use domain-specific error codes, not just HTTP statuses
- Never leak stack traces or internal paths in production error responses
- Log the full error server-side; return a safe summary to the client

## Security
- Authenticate before authorize — verify identity, then check permissions
- Rate-limit write endpoints and authentication routes
- Validate Content-Type headers; reject unexpected media types
