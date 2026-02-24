#!/usr/bin/env bash
# activate.sh — Symlinks base + selected overlays into a target project's .claude/ directory.
#
# Usage:
#   ./activate.sh <target-project-path> <overlay1> [overlay2] ...
#   ./activate.sh <target-project-path> --composition <composition-name>
#   ./activate.sh <target-project-path> <overlay1> --with-externals
#   ./activate.sh <target-project-path> <overlay1> --external agent <category/name>
#
# Examples:
#   ./activate.sh ~/my-app web-dev quality-assurance
#   ./activate.sh ~/my-app --composition fullstack-web
#   ./activate.sh ~/my-app web-dev --with-externals
#   ./activate.sh ~/my-app web-dev --external agent development-team/frontend-developer

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$SCRIPT_DIR/base"
OVERLAYS_DIR="$SCRIPT_DIR/overlays"
PERSONAS_DIR="$SCRIPT_DIR/personas"
AGENTS_DIR="$SCRIPT_DIR/agents"
COMPOSITIONS_DIR="$SCRIPT_DIR/compositions"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"
MANIFEST="$SCRIPT_DIR/manifest.json"
TEMPLATE_VERSION=$(cat "$SCRIPT_DIR/VERSION" 2>/dev/null || echo "unknown")

error() { echo -e "${RED}ERROR:${NC} $1" >&2; exit 1; }
warn() { echo -e "${YELLOW}WARN:${NC} $1" >&2; }
info() { echo -e "${GREEN}>>>${NC} $1"; }

usage() {
    echo "Usage: $0 <target-project-path> <overlay1> [overlay2] ... [OPTIONS]"
    echo "       $0 <target-project-path> --composition <composition-name> [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --with-externals                  Install recommended external components from active overlays"
    echo "  --external <type> <category/name> Install a specific external component (type: agent|command|skill|mcp|hook|setting)"
    echo "  --browse                          Launch interactive component browser after activation"
    echo ""
    echo "Available overlays:"
    for d in "$OVERLAYS_DIR"/*/; do
        [ -d "$d" ] && echo "  - $(basename "$d")"
    done
    echo ""
    echo "Available compositions:"
    for f in "$COMPOSITIONS_DIR"/*.json; do
        [ -f "$f" ] && echo "  - $(basename "$f" .json)"
    done
    exit 1
}

# --- Argument parsing ---

[ $# -lt 2 ] && usage

TARGET="$(cd "$1" 2>/dev/null && pwd)" || error "Target directory not found: $1"
shift

OVERLAYS=()
WITH_EXTERNALS=false
EXTERNAL_INSTALLS=()
BROWSE_AFTER=false

if [ "$1" = "--composition" ]; then
    [ $# -lt 2 ] && error "Missing composition name"
    COMP_FILE="$COMPOSITIONS_DIR/$2.json"
    [ -f "$COMP_FILE" ] || error "Composition not found: $2"
    # Parse overlay list from composition JSON
    while IFS= read -r overlay; do
        OVERLAYS+=("$overlay")
    done < <(python3 -c "import json; [print(o) for o in json.load(open('$COMP_FILE'))['overlays']]")
    info "Using composition '$2': ${OVERLAYS[*]}"
    shift 2
    # Parse remaining flags
    while [ $# -gt 0 ]; do
        case "$1" in
            --with-externals) WITH_EXTERNALS=true; shift ;;
            --external) EXTERNAL_INSTALLS+=("$2|$3"); shift 3 ;;
            --browse) BROWSE_AFTER=true; shift ;;
            *) error "Unknown option after composition: $1" ;;
        esac
    done
else
    # Parse overlays and flags from remaining args
    while [ $# -gt 0 ]; do
        case "$1" in
            --with-externals) WITH_EXTERNALS=true; shift ;;
            --external) EXTERNAL_INSTALLS+=("$2|$3"); shift 3 ;;
            --browse) BROWSE_AFTER=true; shift ;;
            -*) error "Unknown option: $1" ;;
            *) OVERLAYS+=("$1"); shift ;;
        esac
    done
fi

[ ${#OVERLAYS[@]} -eq 0 ] && error "No overlays specified"

# --- Validate overlays exist ---

for overlay in "${OVERLAYS[@]}"; do
    [ -d "$OVERLAYS_DIR/$overlay" ] || error "Overlay not found: $overlay"
done

# --- Check for conflicts ---

info "Checking for conflicts..."
declare -A CONFLICT_MAP

for overlay in "${OVERLAYS[@]}"; do
    OVERLAY_JSON="$OVERLAYS_DIR/$overlay/overlay.json"
    if [ -f "$OVERLAY_JSON" ]; then
        while IFS= read -r conflict; do
            CONFLICT_MAP["$overlay"]+="$conflict "
        done < <(python3 -c "
import json
data = json.load(open('$OVERLAY_JSON'))
for c in data.get('conflicts', []):
    print(c)
" 2>/dev/null)
    fi
done

for overlay in "${OVERLAYS[@]}"; do
    for conflict in ${CONFLICT_MAP["$overlay"]:-}; do
        for other in "${OVERLAYS[@]}"; do
            if [ "$other" = "$conflict" ]; then
                error "Conflict: '$overlay' conflicts with '$other'. Cannot activate both."
            fi
        done
    done
done

# --- Resolve dependencies ---

info "Resolving dependencies..."
RESOLVED_OVERLAYS=("${OVERLAYS[@]}")

for overlay in "${OVERLAYS[@]}"; do
    OVERLAY_JSON="$OVERLAYS_DIR/$overlay/overlay.json"
    if [ -f "$OVERLAY_JSON" ]; then
        while IFS= read -r dep; do
            # Check if dependency is already in the list
            FOUND=0
            for existing in "${RESOLVED_OVERLAYS[@]}"; do
                [ "$existing" = "$dep" ] && FOUND=1 && break
            done
            if [ "$FOUND" -eq 0 ]; then
                [ -d "$OVERLAYS_DIR/$dep" ] || error "Dependency '$dep' (required by '$overlay') not found"
                info "Auto-adding dependency: $dep (required by $overlay)"
                RESOLVED_OVERLAYS+=("$dep")
            fi
        done < <(python3 -c "
import json
data = json.load(open('$OVERLAY_JSON'))
for d in data.get('depends', []):
    print(d)
" 2>/dev/null)
    fi
done

OVERLAYS=("${RESOLVED_OVERLAYS[@]}")

# --- Create target .claude/ directory structure ---

info "Setting up .claude/ directory in $TARGET..."
mkdir -p "$TARGET/.claude/rules"
mkdir -p "$TARGET/.claude/skills"
mkdir -p "$TARGET/.claude/commands"
mkdir -p "$TARGET/.claude/agents"
mkdir -p "$TARGET/.claude/hooks"

# Track all created symlinks for deactivation
CREATED_LINKS=()
CREATED_FILES=()

# --- Symlink base rules (base-- prefix) ---
# Memory files (memory-profile, memory-preferences, memory-decisions, memory-sessions)
# are COPIED instead of symlinked so Claude can edit them in-place per project.

info "Linking base rules..."
if [ -d "$BASE_DIR/rules" ]; then
    for rule in "$BASE_DIR/rules"/*.md; do
        [ -f "$rule" ] || continue
        BASENAME="$(basename "$rule")"
        DEST_NAME="base--$BASENAME"

        if [[ "$BASENAME" == memory-profile.md || "$BASENAME" == memory-preferences.md || \
              "$BASENAME" == memory-decisions.md || "$BASENAME" == memory-sessions.md ]]; then
            # Copy memory files — only if they don't already exist (preserve existing data)
            if [ ! -f "$TARGET/.claude/rules/$DEST_NAME" ]; then
                cp "$rule" "$TARGET/.claude/rules/$DEST_NAME"
                info "  Copied: rules/$DEST_NAME (editable memory file)"
            else
                info "  Skipped: rules/$DEST_NAME (already exists, preserving data)"
            fi
            CREATED_FILES+=(".claude/rules/$DEST_NAME")
        else
            ln -sf "$rule" "$TARGET/.claude/rules/$DEST_NAME"
            CREATED_LINKS+=(".claude/rules/$DEST_NAME")
            info "  Linked: rules/$DEST_NAME"
        fi
    done
fi

# --- Symlink overlay rules ({overlay}-- prefix) ---

info "Linking overlay rules..."
for overlay in "${OVERLAYS[@]}"; do
    if [ -d "$OVERLAYS_DIR/$overlay/rules" ]; then
        for rule in "$OVERLAYS_DIR/$overlay/rules"/*.md; do
            [ -f "$rule" ] || continue
            LINK_NAME="${overlay}--$(basename "$rule")"
            ln -sf "$rule" "$TARGET/.claude/rules/$LINK_NAME"
            CREATED_LINKS+=(".claude/rules/$LINK_NAME")
            info "  Linked: rules/$LINK_NAME"
        done
    fi
done

# --- Symlink persona skills (ALWAYS included) ---

info "Linking persona skills..."
if [ -d "$PERSONAS_DIR" ]; then
    for persona_dir in "$PERSONAS_DIR"/*/; do
        [ -d "$persona_dir" ] || continue
        persona_name=$(basename "$persona_dir")
        ln -sf "$persona_dir" "$TARGET/.claude/skills/$persona_name"
        CREATED_LINKS+=(".claude/skills/$persona_name")
        info "  Linked: skills/$persona_name"
    done
fi

# --- Symlink overlay skills ---

info "Linking overlay skills..."
for overlay in "${OVERLAYS[@]}"; do
    if [ -d "$OVERLAYS_DIR/$overlay/skills" ]; then
        for skill_dir in "$OVERLAYS_DIR/$overlay/skills"/*/; do
            [ -d "$skill_dir" ] || continue
            skill_name=$(basename "$skill_dir")
            ln -sf "$skill_dir" "$TARGET/.claude/skills/$skill_name"
            CREATED_LINKS+=(".claude/skills/$skill_name")
            info "  Linked: skills/$skill_name"
        done
    fi
done

# --- Symlink overlay commands ---

info "Linking overlay commands..."
for overlay in "${OVERLAYS[@]}"; do
    if [ -d "$OVERLAYS_DIR/$overlay/commands" ]; then
        for cmd in "$OVERLAYS_DIR/$overlay/commands"/*.md; do
            [ -f "$cmd" ] || continue
            ln -sf "$cmd" "$TARGET/.claude/commands/$(basename "$cmd")"
            CREATED_LINKS+=(".claude/commands/$(basename "$cmd")")
            info "  Linked: commands/$(basename "$cmd")"
        done
    fi
done

# --- Symlink agents ---

info "Linking agents..."
if [ -d "$AGENTS_DIR" ]; then
    for agent in "$AGENTS_DIR"/*.md; do
        [ -f "$agent" ] || continue
        ln -sf "$agent" "$TARGET/.claude/agents/$(basename "$agent")"
        CREATED_LINKS+=(".claude/agents/$(basename "$agent")")
        info "  Linked: agents/$(basename "$agent")"
    done
fi

# --- Copy hooks ---

info "Copying hooks..."
if [ -d "$BASE_DIR/hooks" ]; then
    for hook in "$BASE_DIR/hooks"/*; do
        [ -f "$hook" ] || continue
        cp "$hook" "$TARGET/.claude/hooks/$(basename "$hook")"
        chmod +x "$TARGET/.claude/hooks/$(basename "$hook")"
        CREATED_FILES+=(".claude/hooks/$(basename "$hook")")
        info "  Copied: hooks/$(basename "$hook")"
    done
fi

# --- Deep-merge MCP configs ---

info "Merging MCP configurations..."
MCP_FILES=()
for overlay in "${OVERLAYS[@]}"; do
    MCP="$OVERLAYS_DIR/$overlay/mcp.json"
    [ -f "$MCP" ] && MCP_FILES+=("$MCP")
done

if [ ${#MCP_FILES[@]} -gt 0 ]; then
    python3 "$SCRIPTS_DIR/merge-configs.py" --type mcp --output "$TARGET/.mcp.json" "${MCP_FILES[@]}"
    CREATED_FILES+=(".mcp.json")
    info "  Generated: .mcp.json"
fi

# --- Deep-merge settings ---

info "Merging settings..."
SETTINGS_FILES=("$BASE_DIR/settings.json")
for overlay in "${OVERLAYS[@]}"; do
    SETTINGS="$OVERLAYS_DIR/$overlay/settings.json"
    [ -f "$SETTINGS" ] && SETTINGS_FILES+=("$SETTINGS")
done

python3 "$SCRIPTS_DIR/merge-configs.py" --type settings --output "$TARGET/.claude/settings.json" "${SETTINGS_FILES[@]}"
CREATED_FILES+=(".claude/settings.json")
info "  Generated: .claude/settings.json"

# --- Generate CLAUDE.md from base template ---

info "Generating CLAUDE.md..."
cp "$BASE_DIR/CLAUDE.md" "$TARGET/CLAUDE.md"
CREATED_FILES+=("CLAUDE.md")
info "  Generated: CLAUDE.md"

# --- Record activation state ---

info "Recording activation state..."

# Build JSON arrays via printf to temp files to avoid nested quoting issues
_overlays_json=$(printf '%s\n' "${OVERLAYS[@]}" | python3 -c "import json,sys; print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))")
_links_json=$(printf '%s\n' "${CREATED_LINKS[@]}" | python3 -c "import json,sys; print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))")
_files_json=$(printf '%s\n' "${CREATED_FILES[@]}" | python3 -c "import json,sys; print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))")

python3 -c "
import json
from datetime import datetime, timezone
state = {
    'schema_version': 2,
    'template_version': '${TEMPLATE_VERSION}',
    'activated_at': datetime.now(timezone.utc).isoformat(),
    'overlays': ${_overlays_json},
    'created_links': ${_links_json},
    'created_files': ${_files_json},
    'template_dir': '${SCRIPT_DIR}'
}
with open('${TARGET}/.claude/.activated-overlays.json', 'w') as f:
    json.dump(state, f, indent=2)
    f.write('\n')
"
info "  Saved: .claude/.activated-overlays.json"

# Register in .known-projects
KNOWN="$SCRIPT_DIR/.known-projects"
touch "$KNOWN"
grep -qxF "$TARGET" "$KNOWN" 2>/dev/null || echo "$TARGET" >> "$KNOWN"

# --- Install external components ---

EXTERNAL_COUNT=0

if $WITH_EXTERNALS; then
    info "Installing recommended external components..."
    "$SCRIPTS_DIR/fetch-external.sh" install "$TARGET" --recommended
    EXTERNAL_COUNT=$((EXTERNAL_COUNT + 1))
fi

if [ ${#EXTERNAL_INSTALLS[@]} -gt 0 ]; then
    info "Installing specified external components..."
    for ext_spec in "${EXTERNAL_INSTALLS[@]}"; do
        ext_type="${ext_spec%%|*}"
        ext_path="${ext_spec#*|}"
        "$SCRIPTS_DIR/fetch-external.sh" install "$TARGET" "--$ext_type" "$ext_path"
        EXTERNAL_COUNT=$((EXTERNAL_COUNT + 1))
    done
fi

if [ "$EXTERNAL_COUNT" -gt 0 ]; then
    # Re-merge MCP/settings if externals added any
    # (external MCPs are already in .mcp.json via fetch-external.sh, but if we need
    # to ensure local overlays still take precedence, we re-merge local over external)
    info "External components installed. Local overlays retain precedence."
fi

# --- Summary ---

echo ""
echo "============================================"
info "Activation complete!"
echo "  Target:   $TARGET"
echo "  Overlays: ${OVERLAYS[*]}"
echo "  Rules:    $(ls "$TARGET/.claude/rules/" 2>/dev/null | wc -l) files"
echo "  Skills:   $(ls "$TARGET/.claude/skills/" 2>/dev/null | wc -l) directories"
echo "  Commands: $(ls "$TARGET/.claude/commands/" 2>/dev/null | wc -l) files"
echo "  Agents:   $(ls "$TARGET/.claude/agents/" 2>/dev/null | wc -l) files"
echo "============================================"
echo ""
echo "To deactivate: $(dirname "$0")/deactivate.sh $TARGET"

if $BROWSE_AFTER; then
    info "Launching component browser..."
    exec "$SCRIPTS_DIR/browse-catalog.sh" "$TARGET"
fi
