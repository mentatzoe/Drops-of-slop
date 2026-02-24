# Memory & Logging Implementation Plan

Based on the feedback in `docs/user-requirements.md` (commit 308df4bb400ad08635636e96637fab76db1e986a), this plan outlines the necessary adjustments to support synchronous memory updates and `AfterTool` validation, while remaining strictly aligned with our **Zero-Trust, MCP-Driven Architectural Blueprint**.

## 1. Goal Description
The objective is to enforce the "Auto-Update Memory" behavior exactly as specified, shifting from lazy batch-writes to real-time, event-based context tracking. We also need an `AfterTool` hook to act as an execution logger.

However, to maintain architectural integrity (bypassing native flat-file markdown as per the blueprint), the user's requested "Action" for flat-file updates must be mapped directly to our external `engram` Model Context Protocol (MCP).

## 2. Proposed Changes

### Configuration Updates
- **[MODIFY]** `.gemini/settings.json`: Ensure the `AfterTool` lifecycle hook is registered in the JSON payload, triggering the logger cleanly.

### Memory Directives
- **[MODIFY]** `.gemini/rules/memory.md`: 
  We will update the memory rules to codify the trigger-action mechanism requested by the user, but adapt the *Actions* to use synchronous MCP commands instead of flat-file writes (`memory-profile.md` etc.). This aligns with the "Persistent External Memory (MCP)" requirement:
  
  ```markdown
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
  ```

### System Hooks
- **[VERIFY]** `.gemini/hooks/audit-logger.sh`:
  This script natively catches after-action events:
  - Appends execution details (tool name, timestamp, arguments) to `.gemini/audit.log`.
  - Scans for context anomalies (if required).
  - Emits JSON `{"decision": "allow"}` or debug metadata.

## 3. Implementation Steps

1. Update `.gemini/settings.json` to include `"AfterTool": [".gemini/hooks/audit-logger.sh"]`.
2. Overwrite `.gemini/rules/memory.md` with the architecturally-aligned trigger table (using MCP calls).
3. Verify that `.gemini/hooks/audit-logger.sh` is fully executable.
