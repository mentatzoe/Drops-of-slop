# Memory Protocol

- **CRITICAL:** The agent is strictly FORBIDDEN from using the native `save_memory` tool for project context or writing to flat markdown files (to prevent context bloat).
- Redirect all project memory operations to the MCP tools (`engram:mem_save` and `engram:mem_search`).

### Auto-Update Memory (MANDATORY)

**Update memory AS YOU GO, not at the end.** When you learn something new, update immediately using the engram MCP.

| Trigger | Action |
|---------|--------|
| User shares a fact about themselves | → Call `engram:mem_save` with topic "profile" |
| User states a preference | → Call `engram:mem_save` with topic "preferences" |
| A decision is made | → Call `engram:mem_save` with topic "decisions" and date |
| Completing substantive work | → Call `engram:mem_save` with topic "sessions" |

**Skip:** Quick factual questions, trivial tasks with no new info.

**DO NOT ASK. Just trigger the MCP when you learn something.**
