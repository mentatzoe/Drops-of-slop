#!/usr/bin/env bash
# Stop hook: nudge Claude to capture learnings when a session involved
# discoveries, fixes, or corrections.
# Reads conversation context from stdin and pattern-matches for signals.

set -euo pipefail

CONTEXT=$(cat)

# Strong signals: corrections, discoveries, workarounds
STRONG_PATTERNS="fixed|workaround|gotcha|that's wrong|check again|we already|should have|discovered|realized|turns out"
# Weak signals: general problem-solving
WEAK_PATTERNS="error|bug|issue|problem|fail"

if echo "$CONTEXT" | grep -qiE "$STRONG_PATTERNS"; then
  cat << 'EOF'
{
  "decision": "approve",
  "systemMessage": "This session involved fixes or discoveries. Before ending, update the relevant memory files in .claude/rules/ (memory-decisions.md, memory-sessions.md, or memory-profile.md) to capture what was learned."
}
EOF
elif echo "$CONTEXT" | grep -qiE "$WEAK_PATTERNS"; then
  cat << 'EOF'
{
  "decision": "approve",
  "systemMessage": "If you learned something non-obvious this session, update the relevant memory files in .claude/rules/ (memory-decisions.md, memory-sessions.md) before ending."
}
EOF
else
  echo '{"decision": "approve"}'
fi
