#!/usr/bin/env bash
# Stop hook: nudge Claude to capture learnings when a session involved
# discoveries, fixes, or corrections.
# Receives JSON on stdin with stop_hook_active, last_assistant_message, etc.
# Returns {"decision": "block", "reason": "..."} to give Claude another turn,
# or exits 0 (no output) to allow stopping.

set -euo pipefail

INPUT=$(cat)

# Prevent infinite loops: if we already blocked once, allow stopping
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  exit 0
fi

# Extract the last assistant message for pattern matching
LAST_MESSAGE=$(echo "$INPUT" | jq -r '.last_assistant_message // ""')

# Strong signals: corrections, discoveries, workarounds
STRONG_PATTERNS="fixed|workaround|gotcha|that's wrong|check again|we already|should have|discovered|realized|turns out"
# Weak signals: general problem-solving
WEAK_PATTERNS="error|bug|issue|problem|fail"

if echo "$LAST_MESSAGE" | grep -qiE "$STRONG_PATTERNS"; then
  cat << 'EOF'
{
  "decision": "block",
  "reason": "This session involved fixes or discoveries. Before ending, update the relevant memory files in .claude/rules/ (memory-decisions.md, memory-sessions.md, or memory-profile.md) to capture what was learned."
}
EOF
elif echo "$LAST_MESSAGE" | grep -qiE "$WEAK_PATTERNS"; then
  cat << 'EOF'
{
  "decision": "block",
  "reason": "If you learned something non-obvious this session, update the relevant memory files in .claude/rules/ (memory-decisions.md, memory-sessions.md) before ending."
}
EOF
else
  exit 0
fi
