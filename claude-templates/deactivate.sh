#!/usr/bin/env bash
# deactivate.sh — Removes symlinks and generated files created by activate.sh.
# Leaves any user-created files untouched.
#
# Usage:
#   ./deactivate.sh <target-project-path>
#
# Example:
#   ./deactivate.sh ~/my-app

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

error() { echo -e "${RED}ERROR:${NC} $1" >&2; exit 1; }
warn() { echo -e "${YELLOW}WARN:${NC} $1" >&2; }
info() { echo -e "${GREEN}>>>${NC} $1"; }

[ $# -lt 1 ] && error "Usage: $0 <target-project-path>"

TARGET="$(cd "$1" 2>/dev/null && pwd)" || error "Target directory not found: $1"
STATE_FILE="$TARGET/.claude/.activated-overlays.json"

[ -f "$STATE_FILE" ] || error "No activation state found at $STATE_FILE. Was this project activated?"

info "Reading activation state..."

# Parse the state file
CREATED_LINKS=$(python3 -c "
import json
state = json.load(open('$STATE_FILE'))
for link in state.get('created_links', []):
    print(link)
")

CREATED_FILES=$(python3 -c "
import json
state = json.load(open('$STATE_FILE'))
for f in state.get('created_files', []):
    print(f)
")

OVERLAYS=$(python3 -c "
import json
state = json.load(open('$STATE_FILE'))
print(' '.join(state.get('overlays', [])))
")

REMOVED=0
SKIPPED=0

# --- Remove symlinks ---

info "Removing symlinks..."
while IFS= read -r link; do
    [ -z "$link" ] && continue
    FULL_PATH="$TARGET/$link"
    if [ -L "$FULL_PATH" ]; then
        rm "$FULL_PATH"
        info "  Removed symlink: $link"
        ((REMOVED++))
    elif [ -e "$FULL_PATH" ]; then
        warn "  Skipping (not a symlink, may be user-created): $link"
        ((SKIPPED++))
    fi
done <<< "$CREATED_LINKS"

# --- Remove generated files ---

info "Removing generated files..."
while IFS= read -r file; do
    [ -z "$file" ] && continue
    FULL_PATH="$TARGET/$file"
    if [ -f "$FULL_PATH" ]; then
        rm "$FULL_PATH"
        info "  Removed: $file"
        ((REMOVED++))
    fi
done <<< "$CREATED_FILES"

# --- Remove activation state ---

rm "$STATE_FILE"
info "  Removed: .claude/.activated-overlays.json"
((REMOVED++))

# --- Clean up empty directories ---

info "Cleaning up empty directories..."
for dir in "$TARGET/.claude/rules" "$TARGET/.claude/skills" "$TARGET/.claude/commands" "$TARGET/.claude/agents" "$TARGET/.claude/hooks"; do
    if [ -d "$dir" ] && [ -z "$(ls -A "$dir" 2>/dev/null)" ]; then
        rmdir "$dir"
        info "  Removed empty: ${dir#$TARGET/}"
    fi
done

# Remove .claude itself if empty
if [ -d "$TARGET/.claude" ] && [ -z "$(ls -A "$TARGET/.claude" 2>/dev/null)" ]; then
    rmdir "$TARGET/.claude"
    info "  Removed empty: .claude/"
fi

# --- Summary ---

echo ""
echo "============================================"
info "Deactivation complete!"
echo "  Target:   $TARGET"
echo "  Overlays: $OVERLAYS"
echo "  Removed:  $REMOVED items"
echo "  Skipped:  $SKIPPED items (user-created files preserved)"
echo "============================================"
