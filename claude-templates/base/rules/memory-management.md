---
description: Context hygiene and memory discipline
---

# Memory & Context Management

## Memory Files

Persistent knowledge lives in dedicated memory files (auto-loaded from `.claude/rules/`):

| File | Purpose |
|------|---------|
| `memory-profile.md` | Facts about the user, their environment, and project context |
| `memory-preferences.md` | How the user likes things done — code style, communication, workflow |
| `memory-decisions.md` | Dated log of past decisions for consistency |
| `memory-sessions.md` | Rolling summary of recent work (last 10 sessions) |

These files are the source of truth for cross-session knowledge. Update them in-place as you learn — see the auto-update rules in CLAUDE.md.

## Context Hygiene
- Keep task scope narrow — solve one problem per conversation thread
- Summarize findings before switching to a new sub-task
- Use `context: fork` skills for exploratory research to isolate context usage

## When to Persist vs. Discard
- Persist: architectural decisions, API contracts, non-obvious design rationale
- Persist: reproduction steps for bugs, test strategies, deployment procedures
- Discard: intermediate search results, failed approaches (note the conclusion only)
- Discard: verbose tool output once you have extracted the relevant information

## Compact Discipline
- After extensive exploration, summarize key findings in 3-5 bullet points
- Reference file paths and line numbers instead of quoting large code blocks
- Use TodoWrite to track multi-step work — it survives context boundaries
