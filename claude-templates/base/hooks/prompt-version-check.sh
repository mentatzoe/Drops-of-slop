#!/usr/bin/env bash
# UserPromptSubmit hook: checks if the project's template version is behind
# the installed version. Runs once per session (sentinel file prevents repeats).
# Non-blocking — outputs plain text to stdout as additionalContext.

set -euo pipefail

INPUT=$(cat)

# --- Locate project state file ---

STATE_FILE=".claude/.activated-overlays.json"
[ -f "$STATE_FILE" ] || exit 0

# --- Session sentinel: skip if already checked recently (< 4 hours) ---

PROJECT_PATH="$(pwd)"
if command -v md5sum >/dev/null 2>&1; then
  PATH_HASH=$(echo -n "$PROJECT_PATH" | md5sum | cut -d' ' -f1)
else
  PATH_HASH=$(echo -n "$PROJECT_PATH" | md5 -q)
fi
SENTINEL="/tmp/.claude-tpl-vercheck-${PATH_HASH}"

if [ -f "$SENTINEL" ]; then
  # Check age — skip if less than 4 hours old
  SENTINEL_AGE=$(( $(date +%s) - $(date -r "$SENTINEL" +%s 2>/dev/null || stat -c %Y "$SENTINEL" 2>/dev/null || echo 0) ))
  if [ "$SENTINEL_AGE" -lt 14400 ]; then
    exit 0
  fi
fi

# --- Read versions ---

PROJECT_VERSION=$(python3 -c "
import json, sys
try:
    with open('$STATE_FILE') as f:
        state = json.load(f)
    print(state.get('template_version', ''))
except Exception:
    print('')
" 2>/dev/null)

TEMPLATE_DIR=$(python3 -c "
import json, sys
try:
    with open('$STATE_FILE') as f:
        state = json.load(f)
    print(state.get('template_dir', ''))
except Exception:
    print('')
" 2>/dev/null)

# Bail if we can't determine versions
[ -z "$PROJECT_VERSION" ] && exit 0
[ -z "$TEMPLATE_DIR" ] && exit 0
[ -d "$TEMPLATE_DIR" ] || exit 0

VERSION_FILE="$TEMPLATE_DIR/VERSION"
[ -f "$VERSION_FILE" ] || exit 0

INSTALLED_VERSION=$(cat "$VERSION_FILE" 2>/dev/null || echo "")
[ -z "$INSTALLED_VERSION" ] && exit 0

# --- Compare versions ---

if [ "$PROJECT_VERSION" = "$INSTALLED_VERSION" ]; then
  # Versions match — touch sentinel and exit
  touch "$SENTINEL"
  exit 0
fi

# Use sort -V to determine if project is behind
LOWER=$(printf '%s\n%s\n' "$PROJECT_VERSION" "$INSTALLED_VERSION" | sort -V | head -n1)

if [ "$LOWER" = "$PROJECT_VERSION" ] && [ "$PROJECT_VERSION" != "$INSTALLED_VERSION" ]; then
  # Project version is behind installed version
  touch "$SENTINEL"
  echo "[claude-templates] This project is on template v${PROJECT_VERSION} but v${INSTALLED_VERSION} is installed. To update, run: ${TEMPLATE_DIR}/refresh.sh $(pwd)"
else
  # Project version is ahead or equal — no action needed
  touch "$SENTINEL"
  exit 0
fi
