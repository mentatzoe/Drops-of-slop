---
description: Security requirements for all code changes
---

# Security Rules

## Secrets Management
- Always use environment variables for secrets, API keys, and tokens
- Never hardcode credentials in source files, configs, or test fixtures
- Use `.env.example` with placeholder values to document required variables

## Input Validation
- Validate all external input at system boundaries (API endpoints, CLI args, form data)
- Use parameterized queries for all database operations — never string concatenation
- Sanitize user-provided content before rendering in HTML contexts

## Dependency Safety
- Pin dependency versions in lock files
- Review new dependencies before adding — check maintenance status and security advisories
- Prefer well-maintained packages with active security response teams

## File System Safety
- Never construct file paths from user input without validation
- Use allowlists for permitted file extensions and directories
- Avoid shell command construction from dynamic input

## Authentication & Authorization
- Always check authorization before performing state-changing operations
- Use constant-time comparison for token validation
- Set secure defaults: HTTPS, httpOnly cookies, SameSite attributes
