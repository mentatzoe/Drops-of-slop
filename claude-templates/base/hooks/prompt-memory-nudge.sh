#!/usr/bin/env bash
# UserPromptSubmit hook: scans user messages for preference/decision signals
# and injects a context reminder so Claude captures them in real-time.
# Non-blocking — outputs plain text to stdout as additionalContext.

set -euo pipefail

INPUT=$(cat)

PROMPT=$(echo "$INPUT" | jq -r '.prompt // ""')

# Nothing to scan
[ -z "$PROMPT" ] && exit 0

# Preference signals in user's own words
PREFERENCE_PATTERNS="i prefer|i like|i always|i never|i don't like|i want you to|please always|please never|don't ever|i'd rather|my preference|i usually"
# Decision signals
DECISION_PATTERNS="let's go with|i've decided|we'll use|i chose|the decision is|we're going with|let's do"
# Profile/fact signals
PROFILE_PATTERNS="i'm a|i work on|my team|my project|i use|my setup|my environment|i'm based in|my role"

if echo "$PROMPT" | grep -qiE -- "$PREFERENCE_PATTERNS"; then
  echo "The user just stated a preference. Update memory-preferences.md in .claude/rules/ with what they said. Only record what they actually stated — do not record your own suggestions as their preferences."
elif echo "$PROMPT" | grep -qiE -- "$DECISION_PATTERNS"; then
  echo "The user just made a decision. Add a dated entry to memory-decisions.md in .claude/rules/."
elif echo "$PROMPT" | grep -qiE -- "$PROFILE_PATTERNS"; then
  echo "The user just shared a fact about themselves or their project. Update memory-profile.md in .claude/rules/."
else
  exit 0
fi
