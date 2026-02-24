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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"
TEMPLATE_VERSION=$(cat "$SCRIPT_DIR/VERSION" 2>/dev/null || echo "unknown")

error() { echo -e "${RED}ERROR:${NC} $1" >&2; exit 1; }
warn() { echo -e "${YELLOW}WARN:${NC} $1" >&2; }
info() { echo -e "${GREEN}>>>${NC} $1"; }

[ $# -lt 1 ] && error "Usage: $0 <target-project-path>"

TARGET="$(cd "$1" 2>/dev/null && pwd)" || error "Target directory not found: $1"
STATE_FILE="$TARGET/.claude/.activated-overlays.json"

[ -f "$STATE_FILE" ] || error "No activation state found at $STATE_FILE. Was this project activated?"

# Migrate state file to current schema before reading
python3 "$SCRIPTS_DIR/migrate-state.py" "$STATE_FILE" --template-version "$TEMPLATE_VERSION" 2>/dev/null || true

# Check for migration state
IS_MIGRATED=0
MIGRATION_BACKUP=""
if [ -f "$TARGET/.claude/.migration-state.json" ]; then
    IS_MIGRATED=1
    MIGRATION_BACKUP=$(python3 -c "
import json
state = json.load(open('$TARGET/.claude/.migration-state.json'))
print(state.get('backup_dir', ''))
" 2>/dev/null || echo "")
    warn "This project was set up via migrate.sh."
    warn "Deactivating will remove template artifacts but preserve custom-- prefixed rules."
    if [ -n "$MIGRATION_BACKUP" ]; then
        warn "To fully restore pre-migration state, use the backup at:"
        warn "  $MIGRATION_BACKUP"
    fi
    echo ""
fi

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
        REMOVED=$((REMOVED + 1))
    elif [ -e "$FULL_PATH" ]; then
        warn "  Skipping (not a symlink, may be user-created): $link"
        SKIPPED=$((SKIPPED + 1))
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
        REMOVED=$((REMOVED + 1))
    fi
done <<< "$CREATED_FILES"

# --- Remove external components ---

info "Removing external components..."
EXTERNAL_REMOVED=$(python3 -c "
import json, os, shutil

state = json.load(open('$STATE_FILE'))
ec = state.get('external_components', {})
removed = 0

# Remove agents
for agent in ec.get('agents', []):
    path = '$TARGET/' + agent.get('installed_to', '')
    if os.path.isfile(path):
        os.remove(path)
        print(f'  Removed: {agent[\"installed_to\"]}')
        removed += 1

# Remove commands
for cmd in ec.get('commands', []):
    path = '$TARGET/' + cmd.get('installed_to', '')
    if os.path.isfile(path):
        os.remove(path)
        print(f'  Removed: {cmd[\"installed_to\"]}')
        removed += 1

# Remove skills (directories)
for skill in ec.get('skills', []):
    path = '$TARGET/' + skill.get('installed_to', '').rstrip('/')
    if os.path.isdir(path):
        shutil.rmtree(path)
        print(f'  Removed: {skill[\"installed_to\"]}')
        removed += 1

# Remove MCP server entries
for mcp in ec.get('mcps', []):
    servers = mcp.get('servers_added', [])
    mcp_file = '$TARGET/.mcp.json'
    if os.path.isfile(mcp_file) and servers:
        with open(mcp_file) as f:
            mcp_config = json.load(f)
        for srv in servers:
            mcp_config.get('mcpServers', {}).pop(srv, None)
        with open(mcp_file, 'w') as f:
            json.dump(mcp_config, f, indent=2)
            f.write('\n')
        print(f'  Removed MCP servers: {servers}')
        removed += 1

# Remove hook scripts
for hook in ec.get('hooks', []):
    hooks_dir = '$TARGET/.claude/hooks/'
    prefix = 'ext--' + hook['name'] + '--'
    if os.path.isdir(hooks_dir):
        for fname in os.listdir(hooks_dir):
            if fname.startswith(prefix):
                os.remove(os.path.join(hooks_dir, fname))
                print(f'  Removed: .claude/hooks/{fname}')
                removed += 1

# Settings were merged in; they will be removed when settings.json is deleted below

print(removed)
" 2>/dev/null)
EXTERNAL_REMOVED_COUNT=$(echo "$EXTERNAL_REMOVED" | tail -1)
REMOVED=$((REMOVED + EXTERNAL_REMOVED_COUNT))

# --- Remove activation state ---

rm "$STATE_FILE"
info "  Removed: .claude/.activated-overlays.json"
REMOVED=$((REMOVED + 1))

# --- Handle migration-specific cleanup ---

if [ "$IS_MIGRATED" -eq 1 ]; then
    # Remove migration state file
    if [ -f "$TARGET/.claude/.migration-state.json" ]; then
        rm "$TARGET/.claude/.migration-state.json"
        info "  Removed: .claude/.migration-state.json"
        ((REMOVED++))
    fi

    # Restore custom-- prefixed rules to their original names
    if [ -d "$TARGET/.claude/rules" ]; then
        for rule in "$TARGET/.claude/rules"/custom--*.md; do
            [ -f "$rule" ] || continue
            BASENAME=$(basename "$rule")
            ORIGINAL_NAME="${BASENAME#custom--}"
            ORIGINAL_PATH="$TARGET/.claude/rules/$ORIGINAL_NAME"
            if [ ! -f "$ORIGINAL_PATH" ]; then
                mv "$rule" "$ORIGINAL_PATH"
                info "  Restored: rules/$BASENAME -> rules/$ORIGINAL_NAME"
            else
                warn "  Cannot restore rules/$BASENAME (rules/$ORIGINAL_NAME already exists)"
            fi
        done
    fi
fi

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
