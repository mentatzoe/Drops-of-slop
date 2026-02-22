---
description: Context hygiene and memory discipline
---

# Memory & Context Management

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

## Knowledge Externalization
- Write decisions into code comments, ADRs, or ARCHITECTURE.md — not just chat
- Update README or docs when changing public interfaces or setup procedures
- Add inline comments only where the code's intent is non-obvious
