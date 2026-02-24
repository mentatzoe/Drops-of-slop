# Project Guidelines

You are working in a project managed with the claude-templates overlay system.
Rules in `.claude/rules/` are auto-loaded based on file paths. Follow them.

## Quality Standards

- Every change must leave the codebase better than you found it
- Prefer clarity over cleverness — code is read far more than it is written
- Handle errors explicitly at system boundaries; trust internal invariants
- Write tests for new behavior; update tests when changing existing behavior
- Keep functions short and single-purpose; extract when a block needs a comment

## Error Handling Philosophy

- Fail fast and loud — surface errors at the point of detection
- Use typed errors or error codes, not stringly-typed messages
- Never swallow exceptions silently; log or propagate with context
- Validate at entry points (user input, API boundaries), trust internals

## Communication Style

- Be direct and concise — say what needs doing, then do it
- Show reasoning for non-obvious decisions in commit messages and PR descriptions
- Ask clarifying questions early rather than assuming

## Git Workflow

- Read `.claude/rules/base--git-workflow.md` before your first commit
- Atomic commits: one logical change per commit
- Branch names: `feature/`, `fix/`, `refactor/`, `docs/` prefixes

## Architecture & Conventions

- Architecture details live in `.claude/rules/` — they load automatically by path
- For project-specific context, check `docs/` or `ARCHITECTURE.md` if they exist

## When to Read Reference Files

- Before reviewing code: check if a review skill is available via `/skills`
- Before writing new components: check for scaffold commands via `/commands`
- When uncertain about conventions: re-read the relevant rule files in `.claude/rules/`
- For domain-specific knowledge: invoke the appropriate skill — it will load references

## Security

- Never hardcode secrets, tokens, or credentials — use environment variables
- Never commit `.env` files, private keys, or credential files
- Parameterize all database queries — no string concatenation for SQL
- Validate and sanitize all external input

## Auto-Update Memory (MANDATORY)

**Capture as you go, not at the end.** The stop hook is a safety net, not the primary mechanism.

| Trigger | Action |
|---------|--------|
| User shares a fact about themselves | → Update `memory-profile.md` |
| User states a preference | → Update `memory-preferences.md` |
| A decision is made | → Update `memory-decisions.md` with date |
| Completing substantive work | → Add to `memory-sessions.md` |

**How to recognize triggers during work:**
- A terse command style ("commit this", "just do it") → that's a communication preference
- A GitHub handle visible in a PR URL → that's a profile fact
- The user accepts a plan without pushback → that's a workflow preference (trusts autonomous execution)
- You chose approach A over approach B → that's a decision, log it

Skip: Quick factual questions, trivial tasks with no new info.

DO NOT ASK. Just update the files when you learn something.

## Context Discipline

- Keep conversations focused — one task thread at a time
- Use skills with `context: fork` for heavy research to avoid bloating context
- Persist important decisions in code comments or docs, not just in conversation
- When context grows large, summarize findings before continuing
