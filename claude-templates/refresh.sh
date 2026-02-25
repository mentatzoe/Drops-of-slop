#!/usr/bin/env bash
# refresh.sh — Post-update project refresh. Re-links symlinks, re-merges configs,
# and preserves user data (memory files, custom rules, external components).
#
# Usage:
#   ./refresh.sh <target-path>
#   ./refresh.sh --all                   (refreshes all .known-projects)
#   ./refresh.sh --dry-run <target-path>
#   ./refresh.sh --dry-run --all

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$SCRIPT_DIR/base"
OVERLAYS_DIR="$SCRIPT_DIR/overlays"
AGENTS_DIR="$SCRIPT_DIR/agents"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"
TEMPLATE_VERSION=$(cat "$SCRIPT_DIR/VERSION" 2>/dev/null || echo "unknown")

error() { echo -e "${RED}ERROR:${NC} $1" >&2; exit 1; }
warn() { echo -e "${YELLOW}WARN:${NC} $1" >&2; }
info() { echo -e "${GREEN}>>>${NC} $1"; }
dry() { echo -e "${CYAN}[dry-run]${NC} Would: $1"; }

usage() {
    echo "Usage: $0 [--dry-run] <target-path>"
    echo "       $0 [--dry-run] --all"
    echo ""
    echo "Options:"
    echo "  --dry-run    Preview changes without applying"
    echo "  --all        Refresh all projects in .known-projects registry"
    echo ""
    echo "Re-establishes symlinks and re-merges configs after a template update."
    echo "Preserves: memory files, custom rules (custom--*), external components (ext--*),"
    echo "CLAUDE.md user customizations, and hook modifications."
    exit 1
}

# --- Argument parsing ---

DRY_RUN=0
REFRESH_ALL=false
TARGET=""

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN=1; shift ;;
        --all) REFRESH_ALL=true; shift ;;
        --help|-h) usage ;;
        -*) error "Unknown option: $1" ;;
        *) TARGET="$1"; shift ;;
    esac
done

# --- Refresh all projects ---

if $REFRESH_ALL; then
    KNOWN="$SCRIPT_DIR/.known-projects"
    if [ ! -f "$KNOWN" ]; then
        error "No .known-projects registry found. Activate a project first."
    fi

    TOTAL=0
    SUCCESS=0
    FAILED=0
    STALE=0

    while IFS= read -r project_path; do
        [ -z "$project_path" ] && continue
        [[ "$project_path" == \#* ]] && continue

        TOTAL=$((TOTAL + 1))

        if [ ! -d "$project_path" ]; then
            warn "Skipping (directory not found): $project_path"
            STALE=$((STALE + 1))
            continue
        fi

        if [ ! -f "$project_path/.claude/.activated-overlays.json" ]; then
            warn "Skipping (no activation state): $project_path"
            STALE=$((STALE + 1))
            continue
        fi

        echo ""
        echo -e "${BOLD}--- Refreshing: $project_path ---${NC}"

        ARGS=("$project_path")
        [ "$DRY_RUN" -eq 1 ] && ARGS=("--dry-run" "$project_path")

        if "$0" "${ARGS[@]}"; then
            SUCCESS=$((SUCCESS + 1))
        else
            warn "Failed to refresh: $project_path"
            FAILED=$((FAILED + 1))
        fi
    done < "$KNOWN"

    echo ""
    echo "============================================"
    info "Refresh --all complete"
    echo "  Total:   $TOTAL projects"
    echo "  Success: $SUCCESS"
    echo "  Failed:  $FAILED"
    echo "  Stale:   $STALE (missing directory or state)"
    echo "============================================"
    exit 0
fi

# --- Single project refresh ---

[ -z "$TARGET" ] && usage
TARGET="$(cd "$TARGET" 2>/dev/null && pwd)" || error "Target directory not found: $TARGET"

STATE_FILE="$TARGET/.claude/.activated-overlays.json"
[ -f "$STATE_FILE" ] || error "No activation state found at $STATE_FILE. Was this project activated?"

echo ""
echo -e "${BOLD}Refreshing: $TARGET${NC}"
echo ""

# --- Step 1: Migrate state file ---

info "Migrating state file (if needed)..."
if [ "$DRY_RUN" -eq 0 ]; then
    python3 "$SCRIPTS_DIR/migrate-state.py" "$STATE_FILE" --template-version "$TEMPLATE_VERSION" 2>/dev/null || true
else
    dry "migrate state file to schema v2"
fi

# --- Step 2: Read state ---

info "Reading activation state..."
STATE=$(python3 -c "
import json
with open('$STATE_FILE') as f:
    state = json.load(f)
# Print tab-separated: overlays, template_dir
print('\t'.join([
    ' '.join(state.get('overlays', [])),
    state.get('template_dir', ''),
]))
")

OVERLAYS_STR=$(echo "$STATE" | cut -f1)
OLD_TEMPLATE_DIR=$(echo "$STATE" | cut -f2)
read -ra OVERLAYS <<< "$OVERLAYS_STR"

if [ ${#OVERLAYS[@]} -eq 0 ]; then
    error "No overlays found in state file."
fi

info "  Overlays: ${OVERLAYS[*]}"

# --- Step 3: Validate template_dir ---

if [ -n "$OLD_TEMPLATE_DIR" ] && [ "$OLD_TEMPLATE_DIR" != "$SCRIPT_DIR" ]; then
    warn "Template directory has moved: $OLD_TEMPLATE_DIR -> $SCRIPT_DIR"
    info "  State will be updated with new path."
fi

# --- Step 4: Validate overlays still exist ---

VALID_OVERLAYS=()
for overlay in "${OVERLAYS[@]}"; do
    if [ ! -d "$OVERLAYS_DIR/$overlay" ]; then
        warn "Overlay '$overlay' no longer exists in templates. Removing its symlinks."
        # Clean up stale symlinks for this removed overlay
        for stale in "$TARGET/.claude/rules/${overlay}--"*; do
            [ -L "$stale" ] || continue
            if [ "$DRY_RUN" -eq 1 ]; then
                dry "remove stale symlink: ${stale#$TARGET/}"
            else
                rm "$stale"
                info "  Removed stale: ${stale#$TARGET/}"
            fi
        done
    else
        VALID_OVERLAYS+=("$overlay")
    fi
done
OVERLAYS=("${VALID_OVERLAYS[@]}")

# Also clean any broken symlinks in .claude/ (e.g. skills, commands, agents)
info "Cleaning broken symlinks..."
for dir in "$TARGET/.claude/rules" "$TARGET/.claude/skills" "$TARGET/.claude/commands" "$TARGET/.claude/agents"; do
    [ -d "$dir" ] || continue
    for link in "$dir"/*; do
        [ -L "$link" ] || continue
        if [ ! -e "$link" ]; then
            if [ "$DRY_RUN" -eq 1 ]; then
                dry "remove broken symlink: ${link#$TARGET/}"
            else
                rm "$link"
                info "  Removed broken: ${link#$TARGET/}"
            fi
        fi
    done
done

# --- Step 5: Read old created_links from state ---

OLD_LINKS=$(python3 -c "
import json
with open('$STATE_FILE') as f:
    state = json.load(f)
for link in state.get('created_links', []):
    print(link)
" 2>/dev/null || true)

# --- Step 6: Remove old symlinks (only actual symlinks) ---

info "Cleaning old symlinks..."
REMOVED=0
while IFS= read -r link; do
    [ -z "$link" ] && continue
    FULL_PATH="$TARGET/$link"
    if [ -L "$FULL_PATH" ]; then
        if [ "$DRY_RUN" -eq 1 ]; then
            dry "remove symlink: $link"
        else
            rm "$FULL_PATH"
        fi
        REMOVED=$((REMOVED + 1))
    elif [ -e "$FULL_PATH" ]; then
        warn "  Skipping (not a symlink, user file): $link"
    fi
done <<< "$OLD_LINKS"
info "  Removed $REMOVED old symlinks"

# --- Step 7: Re-create symlinks ---

CREATED_LINKS=()
CREATED_FILES=()

# Ensure directory structure
for dir in rules skills commands agents hooks; do
    [ -d "$TARGET/.claude/$dir" ] || {
        if [ "$DRY_RUN" -eq 1 ]; then
            dry "mkdir $TARGET/.claude/$dir"
        else
            mkdir -p "$TARGET/.claude/$dir"
        fi
    }
done

# Base rules (non-memory only — memory files are copies, never re-linked)
info "Re-linking base rules..."
if [ -d "$BASE_DIR/rules" ]; then
    for rule in "$BASE_DIR/rules"/*.md; do
        [ -f "$rule" ] || continue
        BASENAME="$(basename "$rule")"
        DEST_NAME="base--$BASENAME"

        # Memory files: skip (they're user-editable copies, not symlinks)
        if [[ "$BASENAME" == memory-profile.md || "$BASENAME" == memory-preferences.md || \
              "$BASENAME" == memory-decisions.md || "$BASENAME" == memory-sessions.md ]]; then
            CREATED_FILES+=(".claude/rules/$DEST_NAME")
            continue
        fi

        if [ "$DRY_RUN" -eq 1 ]; then
            dry "symlink rules/$DEST_NAME"
        else
            ln -sf "$rule" "$TARGET/.claude/rules/$DEST_NAME"
        fi
        CREATED_LINKS+=(".claude/rules/$DEST_NAME")
    done
fi

# Overlay rules
info "Re-linking overlay rules..."
for overlay in "${OVERLAYS[@]}"; do
    [ -d "$OVERLAYS_DIR/$overlay/rules" ] || continue
    for rule in "$OVERLAYS_DIR/$overlay/rules"/*.md; do
        [ -f "$rule" ] || continue
        LINK_NAME="${overlay}--$(basename "$rule")"
        if [ "$DRY_RUN" -eq 1 ]; then
            dry "symlink rules/$LINK_NAME"
        else
            ln -sf "$rule" "$TARGET/.claude/rules/$LINK_NAME"
        fi
        CREATED_LINKS+=(".claude/rules/$LINK_NAME")
    done
done

# Overlay skills
info "Re-linking overlay skills..."
for overlay in "${OVERLAYS[@]}"; do
    [ -d "$OVERLAYS_DIR/$overlay/skills" ] || continue
    for skill_dir in "$OVERLAYS_DIR/$overlay/skills"/*/; do
        [ -d "$skill_dir" ] || continue
        skill_name=$(basename "$skill_dir")
        if [ "$DRY_RUN" -eq 1 ]; then
            dry "symlink skills/$skill_name"
        else
            ln -sf "$skill_dir" "$TARGET/.claude/skills/$skill_name"
        fi
        CREATED_LINKS+=(".claude/skills/$skill_name")
    done
done

# Overlay commands
info "Re-linking overlay commands..."
for overlay in "${OVERLAYS[@]}"; do
    [ -d "$OVERLAYS_DIR/$overlay/commands" ] || continue
    for cmd in "$OVERLAYS_DIR/$overlay/commands"/*.md; do
        [ -f "$cmd" ] || continue
        CMD_NAME=$(basename "$cmd")
        if [ "$DRY_RUN" -eq 1 ]; then
            dry "symlink commands/$CMD_NAME"
        else
            ln -sf "$cmd" "$TARGET/.claude/commands/$CMD_NAME"
        fi
        CREATED_LINKS+=(".claude/commands/$CMD_NAME")
    done
done

# Agents
info "Re-linking agents..."
if [ -d "$AGENTS_DIR" ]; then
    for agent in "$AGENTS_DIR"/*.md; do
        [ -f "$agent" ] || continue
        AGENT_NAME=$(basename "$agent")
        if [ "$DRY_RUN" -eq 1 ]; then
            dry "symlink agents/$AGENT_NAME"
        else
            ln -sf "$agent" "$TARGET/.claude/agents/$AGENT_NAME"
        fi
        CREATED_LINKS+=(".claude/agents/$AGENT_NAME")
    done
fi

# --- Step 8: Re-merge configs ---

info "Re-merging MCP configurations..."
MCP_FILES=()
for overlay in "${OVERLAYS[@]}"; do
    MCP="$OVERLAYS_DIR/$overlay/mcp.json"
    [ -f "$MCP" ] && MCP_FILES+=("$MCP")
done

if [ ${#MCP_FILES[@]} -gt 0 ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
        dry "merge ${#MCP_FILES[@]} MCP config(s) -> .mcp.json"
    else
        # Preserve external MCP servers
        EXTERNAL_SERVERS=""
        if [ -f "$TARGET/.mcp.json" ]; then
            EXTERNAL_SERVERS=$(python3 -c "
import json

with open('$STATE_FILE') as f:
    state = json.load(f)

ec = state.get('external_components', {})
ext_server_names = set()
for mcp in ec.get('mcps', []):
    for srv in mcp.get('servers_added', []):
        ext_server_names.add(srv)

if not ext_server_names:
    exit(0)

with open('$TARGET/.mcp.json') as f:
    mcp_config = json.load(f)

ext_servers = {}
for name in ext_server_names:
    if name in mcp_config.get('mcpServers', {}):
        ext_servers[name] = mcp_config['mcpServers'][name]

if ext_servers:
    print(json.dumps(ext_servers))
" 2>/dev/null || true)
        fi

        # Re-merge overlay MCP configs
        python3 "$SCRIPTS_DIR/merge-configs.py" --type mcp --output "$TARGET/.mcp.json" "${MCP_FILES[@]}"

        # Overlay saved external servers back on top
        if [ -n "$EXTERNAL_SERVERS" ]; then
            python3 -c "
import json

with open('$TARGET/.mcp.json') as f:
    mcp_config = json.load(f)

ext_servers = json.loads('$EXTERNAL_SERVERS')
mcp_config.setdefault('mcpServers', {}).update(ext_servers)

with open('$TARGET/.mcp.json', 'w') as f:
    json.dump(mcp_config, f, indent=2)
    f.write('\n')
" 2>/dev/null || true
        fi
    fi
    CREATED_FILES+=(".mcp.json")
fi

info "Re-merging settings..."
SETTINGS_FILES=("$BASE_DIR/settings.json")
for overlay in "${OVERLAYS[@]}"; do
    SETTINGS="$OVERLAYS_DIR/$overlay/settings.json"
    [ -f "$SETTINGS" ] && SETTINGS_FILES+=("$SETTINGS")
done

if [ -f "$TARGET/.claude/settings.local.json" ]; then
    SETTINGS_FILES+=("$TARGET/.claude/settings.local.json")
    info "  Including: settings.local.json (local overrides, highest precedence)"
fi

if [ "$DRY_RUN" -eq 1 ]; then
    dry "merge ${#SETTINGS_FILES[@]} settings file(s) -> .claude/settings.json"
else
    python3 "$SCRIPTS_DIR/merge-configs.py" --type settings --output "$TARGET/.claude/settings.json" "${SETTINGS_FILES[@]}"
fi
CREATED_FILES+=(".claude/settings.json")

# --- Step 9: Check hooks ---

info "Checking hooks..."
if [ -d "$BASE_DIR/hooks" ]; then
    for hook in "$BASE_DIR/hooks"/*; do
        [ -f "$hook" ] || continue
        HOOK_NAME=$(basename "$hook")
        DEST="$TARGET/.claude/hooks/$HOOK_NAME"

        if [ -f "$DEST" ]; then
            # Compare template hook to installed hook
            if ! diff -q "$hook" "$DEST" >/dev/null 2>&1; then
                warn "  Hook differs from template: hooks/$HOOK_NAME"
                echo "    To update: cp \"$hook\" \"$DEST\" && chmod +x \"$DEST\""
            fi
        else
            if [ "$DRY_RUN" -eq 1 ]; then
                dry "install new hook: hooks/$HOOK_NAME"
            else
                cp "$hook" "$DEST"
                chmod +x "$DEST"
                info "  Installed new hook: hooks/$HOOK_NAME"
            fi
        fi
    done
fi

# --- Step 10: Update state file ---

info "Updating state file..."
if [ "$DRY_RUN" -eq 1 ]; then
    dry "update state with new template_version, template_dir, created_links, refreshed_at"
else
    _overlays_json=$(printf '%s\n' "${OVERLAYS[@]}" | python3 -c "import json,sys; print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))")
    _links_json=$(printf '%s\n' "${CREATED_LINKS[@]}" | python3 -c "import json,sys; print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))")
    _files_json=$(printf '%s\n' "${CREATED_FILES[@]}" | python3 -c "import json,sys; print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))")

    python3 -c "
import json
from datetime import datetime, timezone

with open('$STATE_FILE') as f:
    state = json.load(f)

# Update fields
state['template_version'] = '$TEMPLATE_VERSION'
state['template_dir'] = '$SCRIPT_DIR'
state['created_links'] = ${_links_json}
state['created_files'] = state.get('created_files', [])
# Merge new created_files with any existing ones not already present
for f in ${_files_json}:
    if f not in state['created_files']:
        state['created_files'].append(f)
state['refreshed_at'] = datetime.now(timezone.utc).isoformat()

with open('$STATE_FILE', 'w') as f:
    json.dump(state, f, indent=2)
    f.write('\n')
"
fi

# --- Summary ---

echo ""
echo "============================================"
if [ "$DRY_RUN" -eq 1 ]; then
    echo -e "${CYAN}DRY RUN — no changes were made${NC}"
else
    info "Refresh complete!"
fi
echo "  Target:   $TARGET"
echo "  Overlays: ${OVERLAYS[*]}"
echo "  Version:  $TEMPLATE_VERSION"
echo "  Links:    ${#CREATED_LINKS[@]} symlinks"
if [ "$DRY_RUN" -eq 0 ]; then
    echo ""
    echo "  Preserved (untouched):"
    echo "    - Memory files (base--memory-*.md)"
    echo "    - Custom rules (custom--*)"
    echo "    - External components (ext--*)"
    echo "    - CLAUDE.md"
fi
echo "============================================"
echo ""
