---
description: Rolling summary of recent work sessions
---

# Session Log

<!-- Claude: Add a summary after completing substantive work. -->
<!-- Keep only the last 10 sessions. Prune the oldest when adding new ones. -->
<!-- Format: -->
<!-- ## YYYY-MM-DD: Brief title -->
<!-- - What was accomplished -->
<!-- - Key files changed -->
<!-- - Open threads or next steps -->

<!-- Entries below, newest first -->

## 2026-02-24: Template audit — fix drift, portability, and add test suite
- Implemented 7-item audit of `claude-templates/` (excluding gemini-cli-template)
- Critical: Fixed `pre-commit-safety.sh` template drift — ported JSON protocol from active copy back to template source
- High: Replaced `grep -P` (Perl regex) with `grep -E` (POSIX ERE) + `--` for option termination; fixed `file` command to use `--mime` for binary detection
- High: Created 43-test bats suite across 5 files: activation, hooks, conflicts-deps, refresh, settings-merge
- Medium: Integrated `settings.local.json` into activate.sh and refresh.sh (merged last for highest precedence)
- Medium: Added circular dependency detection with `_DEP_VISITING` associative array
- Medium: refresh.sh now removes stale/broken symlinks from deleted overlays
- Medium: activate.sh now warns about unset `${...}` env vars in MCP configs
- Bonus: Removed blanket `WebFetch` and `Bash(curl:*)` deny from base settings.json template
- Key files: `claude-templates/base/hooks/pre-commit-safety.sh`, `claude-templates/activate.sh`, `claude-templates/refresh.sh`, `claude-templates/base/settings.json`, `claude-templates/tests/*.bats`
- Branch: `fix/template-audit-fixes`

## 2026-02-24: Fix stop-learning-capture.sh hook and add test infra
- Fixed Stop hook so it actually triggers memory updates instead of just displaying a message
- Three bugs fixed:
  1. `"approve"` + `systemMessage` is display-only — changed to `"block"` + `reason` so Claude gets another turn
  2. Stdin is JSON, not raw text — now uses `jq` to parse `last_assistant_message` and `stop_hook_active`
  3. No loop prevention — now checks `stop_hook_active` and exits cleanly on second invocation
- Replaced vendored bats helpers with git submodules (bats-assert v2.2.4, bats-support v0.3.0, bats-file v0.4.0)
- Key files changed: `claude-templates/base/hooks/stop-learning-capture.sh`, `.gitmodules`
- PR #18 on `fix/stop-hook-memory-trigger` branch

## 2026-02-24: Debug activation of quality-assurance overlay
- Activated `quality-assurance` overlay against the repo itself for debugging
- Used `.git/info/exclude` to keep all generated files invisible to git
- Fixed three bugs:
  1. Blanket `WebFetch` and `Bash(curl:*)` deny rules overriding domain-scoped allows — removed from deny, merged local allows
  2. `pre-commit-safety.sh` not registered as a `PreToolUse` hook — added to `hooks` section in settings
  3. Hook outputting plain text + exit codes instead of JSON protocol — rewrote to emit `{"decision": "approve"|"block"}`
- Key files changed: `.claude/settings.json`, `.claude/hooks/pre-commit-safety.sh`, `.git/info/exclude`
- To clean up: run `deactivate.sh` then remove added lines from `.git/info/exclude`
