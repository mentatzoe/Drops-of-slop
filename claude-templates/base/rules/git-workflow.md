---
description: Git commit and branch conventions
---

# Git Workflow

## Commit Messages
- Format: `<type>: <concise description of why>`
- Types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `perf`
- Body (optional): explain motivation, not mechanics — the diff shows the what
- Keep subject line under 72 characters

## Branch Naming
- `feature/<short-description>` — new functionality
- `fix/<short-description>` — bug fixes
- `refactor/<short-description>` — code restructuring without behavior change
- `docs/<short-description>` — documentation only

## Commit Hygiene
- One logical change per commit — reviewable in isolation
- Never commit generated files, build artifacts, or secrets
- Stage specific files; avoid `git add -A` to prevent accidental inclusions
- Run tests before committing; a commit should not knowingly break the build

## Pull Requests
- Title: same format as commit subject lines
- Description: what changed, why, how to test, any migration steps
- Keep PRs small — under 400 lines of diff when possible
- Link related issues in the PR description

## Pre-Push Checklist
- All tests pass locally
- No linter warnings introduced
- No secrets or credentials staged
- Commit history is clean (no fixup commits left unsquashed)
