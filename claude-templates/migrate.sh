#!/usr/bin/env bash
# migrate.sh — Analyze an existing project, auto-detect overlays, and migrate
# to the claude-templates overlay architecture while preserving custom config.
#
# Usage:
#   ./migrate.sh <target-project-path>                          # Interactive (default)
#   ./migrate.sh <target-project-path> --auto                   # Accept auto-detected overlays
#   ./migrate.sh <target-project-path> --overlays web-dev qa    # Specify overlays manually
#   ./migrate.sh <target-project-path> --composition fullstack-web
#   ./migrate.sh <target-project-path> --dry-run                # Preview changes only
#   ./migrate.sh <target-project-path> --no-backup              # Skip backup step
#
# Flags can be combined: ./migrate.sh ~/app --auto --dry-run

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
PERSONAS_DIR="$SCRIPT_DIR/personas"
AGENTS_DIR="$SCRIPT_DIR/agents"
COMPOSITIONS_DIR="$SCRIPT_DIR/compositions"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"
MANIFEST="$SCRIPT_DIR/manifest.json"

error() { echo -e "${RED}ERROR:${NC} $1" >&2; exit 1; }
warn() { echo -e "${YELLOW}WARN:${NC} $1" >&2; }
info() { echo -e "${GREEN}>>>${NC} $1"; }
dry() { echo -e "${CYAN}[dry-run]${NC} Would: $1"; }
verbose() { [ "$VERBOSE" -eq 1 ] && echo -e "${CYAN}  [verbose]${NC} $1" || true; }

# --- Argument parsing ---

usage() {
    echo "Usage: $0 <target-project-path> [options]"
    echo ""
    echo "Options:"
    echo "  --auto               Accept auto-detected overlays without confirmation"
    echo "  --overlays O1 O2     Specify overlays manually (overrides auto-detection)"
    echo "  --composition NAME   Use a pre-built composition"
    echo "  --dry-run            Preview changes without applying"
    echo "  --no-backup          Skip backup step"
    echo "  --force              Re-migrate even if already migrated"
    echo "  --verbose            Show detailed output"
    echo "  --backup-dir PATH    Custom backup directory (default: .claude/.migration-backup/)"
    echo ""
    echo "Examples:"
    echo "  $0 ~/my-app                           # Interactive mode"
    echo "  $0 ~/my-app --auto                    # Auto-detect and apply"
    echo "  $0 ~/my-app --overlays web-dev        # Manual overlay selection"
    echo "  $0 ~/my-app --composition fullstack-web"
    echo "  $0 ~/my-app --dry-run                 # Preview only"
    echo "  $0 ~/my-app --auto --force            # Re-migrate over existing"
    echo "  $0 ~/my-app --auto --verbose          # Detailed output"
    exit 1
}

[ $# -lt 1 ] && usage

TARGET="$(cd "$1" 2>/dev/null && pwd)" || error "Target directory not found: $1"
shift

AUTO_MODE=0
DRY_RUN=0
NO_BACKUP=0
FORCE=0
VERBOSE=0
CUSTOM_BACKUP_DIR=""
MANUAL_OVERLAYS=()
COMPOSITION=""

while [ $# -gt 0 ]; do
    case "$1" in
        --auto)
            AUTO_MODE=1
            shift
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --no-backup)
            NO_BACKUP=1
            shift
            ;;
        --force)
            FORCE=1
            shift
            ;;
        --verbose)
            VERBOSE=1
            shift
            ;;
        --backup-dir)
            [ $# -lt 2 ] && error "Missing backup directory path"
            CUSTOM_BACKUP_DIR="$2"
            shift 2
            ;;
        --composition)
            [ $# -lt 2 ] && error "Missing composition name"
            COMPOSITION="$2"
            shift 2
            ;;
        --overlays)
            shift
            while [ $# -gt 0 ] && [[ "$1" != --* ]]; do
                MANUAL_OVERLAYS+=("$1")
                shift
            done
            ;;
        *)
            error "Unknown option: $1"
            ;;
    esac
done

# Wrapper functions for dry-run support
do_mkdir() {
    if [ "$DRY_RUN" -eq 1 ]; then
        dry "mkdir -p $1"
    else
        mkdir -p "$1"
    fi
}

do_ln() {
    if [ "$DRY_RUN" -eq 1 ]; then
        dry "symlink $2 -> $1"
    else
        ln -sf "$1" "$2"
    fi
}

do_cp() {
    if [ "$DRY_RUN" -eq 1 ]; then
        dry "copy $1 -> $2"
    else
        cp "$1" "$2"
    fi
}

do_mv() {
    if [ "$DRY_RUN" -eq 1 ]; then
        dry "rename $1 -> $2"
    else
        mv "$1" "$2"
    fi
}

# ============================================================
# PHASE 1: Detection
# ============================================================

echo ""
echo -e "${BOLD}=== Phase 1: Project Analysis ===${NC}"
echo ""

DETECTION=$("$SCRIPTS_DIR/detect-project.sh" "$TARGET")

# Parse detection results
DETECTED_OVERLAYS=$(echo "$DETECTION" | python3 -c "import sys,json; print(' '.join(json.load(sys.stdin)['recommended_overlays']))")
DETECTED_COMPOSITION=$(echo "$DETECTION" | python3 -c "import sys,json; c=json.load(sys.stdin)['recommended_composition']; print(c if c else '')")
DETECTED_LANGUAGES=$(echo "$DETECTION" | python3 -c "import sys,json; print(', '.join(json.load(sys.stdin)['languages']) or 'none detected')")
DETECTED_FRAMEWORKS=$(echo "$DETECTION" | python3 -c "import sys,json; print(', '.join(json.load(sys.stdin)['frameworks']) or 'none detected')")
HAS_EXISTING_CONFIG=$(echo "$DETECTION" | python3 -c "
import sys,json
cfg = json.load(sys.stdin)['existing_claude_config']
existing = []
if cfg['has_claude_md']: existing.append('CLAUDE.md')
if cfg['has_claude_dir']: existing.append('.claude/')
if cfg['has_mcp_json']: existing.append('.mcp.json')
if cfg['has_settings']: existing.append('settings.json')
print(', '.join(existing) if existing else 'none')
")

echo "  Target:      $TARGET"
echo "  Languages:   $DETECTED_LANGUAGES"
echo "  Frameworks:  $DETECTED_FRAMEWORKS"
echo "  Existing:    $HAS_EXISTING_CONFIG"
echo ""

# Display detection signals
echo "$DETECTION" | python3 -c "
import sys, json
data = json.load(sys.stdin)
signals = data.get('signals', {})
if signals:
    print('  Detection signals:')
    for overlay, sigs in signals.items():
        for s in sigs:
            print(f'    [{overlay}] {s}')
    print()
"

verbose "Raw detection JSON:"
[ "$VERBOSE" -eq 1 ] && echo "$DETECTION" | python3 -c "import sys,json; print(json.dumps(json.load(sys.stdin), indent=2))" | sed 's/^/    /'

# Check if already migrated
if [ -f "$TARGET/.claude/.migration-state.json" ]; then
    if [ "$FORCE" -eq 0 ]; then
        PREV_OVERLAYS=$(python3 -c "
import json
state = json.load(open('$TARGET/.claude/.migration-state.json'))
print(' '.join(state.get('overlays', [])))
" 2>/dev/null || echo "unknown")
        error "Project already migrated (overlays: $PREV_OVERLAYS). Use --force to re-migrate."
    else
        warn "Project already migrated. Re-migrating with --force."
    fi
fi

# Check if already activated
ALREADY_ACTIVATED=0
if [ -f "$TARGET/.claude/.activated-overlays.json" ]; then
    ALREADY_ACTIVATED=1
    EXISTING_OVERLAYS=$(python3 -c "
import json
state = json.load(open('$TARGET/.claude/.activated-overlays.json'))
print(' '.join(state.get('overlays', [])))
")
    warn "Project already uses claude-templates (overlays: $EXISTING_OVERLAYS)"
    echo "  The migrator will deactivate the existing setup and re-migrate."
    echo ""
fi

# ============================================================
# PHASE 2: Overlay Selection
# ============================================================

echo -e "${BOLD}=== Phase 2: Overlay Selection ===${NC}"
echo ""

OVERLAYS=()

if [ -n "$COMPOSITION" ]; then
    # Composition mode
    COMP_FILE="$COMPOSITIONS_DIR/$COMPOSITION.json"
    [ -f "$COMP_FILE" ] || error "Composition not found: $COMPOSITION"
    while IFS= read -r overlay; do
        OVERLAYS+=("$overlay")
    done < <(python3 -c "import json; [print(o) for o in json.load(open('$COMP_FILE'))['overlays']]")
    info "Using composition '$COMPOSITION': ${OVERLAYS[*]}"

elif [ ${#MANUAL_OVERLAYS[@]} -gt 0 ]; then
    # Manual overlay mode
    OVERLAYS=("${MANUAL_OVERLAYS[@]}")
    info "Using specified overlays: ${OVERLAYS[*]}"

elif [ "$AUTO_MODE" -eq 1 ]; then
    # Auto mode
    if [ -z "$DETECTED_OVERLAYS" ]; then
        error "Auto-detection found no overlays to recommend. Specify overlays manually with --overlays."
    fi
    read -ra OVERLAYS <<< "$DETECTED_OVERLAYS"
    info "Auto-detected overlays: ${OVERLAYS[*]}"
    if [ -n "$DETECTED_COMPOSITION" ]; then
        info "Matches composition: $DETECTED_COMPOSITION"
    fi

else
    # Interactive mode
    if [ -z "$DETECTED_OVERLAYS" ]; then
        echo "  No overlays auto-detected. Available overlays:"
        for d in "$OVERLAYS_DIR"/*/; do
            [ -d "$d" ] || continue
            OVERLAY_NAME=$(basename "$d")
            DESC=$(python3 -c "import json; print(json.load(open('$d/overlay.json')).get('description',''))" 2>/dev/null || echo "")
            echo "    - $OVERLAY_NAME: $DESC"
        done
        echo ""
        echo -n "  Enter overlays (space-separated): "
        read -r USER_INPUT
        read -ra OVERLAYS <<< "$USER_INPUT"
    else
        read -ra AUTO_OVERLAYS <<< "$DETECTED_OVERLAYS"
        echo "  Recommended overlays:"
        for overlay in "${AUTO_OVERLAYS[@]}"; do
            echo -e "    ${GREEN}+${NC} $overlay"
        done
        if [ -n "$DETECTED_COMPOSITION" ]; then
            echo -e "    (matches composition: ${CYAN}$DETECTED_COMPOSITION${NC})"
        fi
        echo ""
        echo -n "  Accept these overlays? [Y/n/edit] "
        read -r REPLY
        case "${REPLY,,}" in
            n|no)
                echo "  Available overlays:"
                for d in "$OVERLAYS_DIR"/*/; do
                    [ -d "$d" ] || continue
                    echo "    - $(basename "$d")"
                done
                echo ""
                echo -n "  Enter overlays (space-separated): "
                read -r USER_INPUT
                read -ra OVERLAYS <<< "$USER_INPUT"
                ;;
            e|edit)
                echo -n "  Enter overlays (space-separated, starting with auto-detected): "
                echo -n "  [${AUTO_OVERLAYS[*]}] "
                read -r USER_INPUT
                if [ -z "$USER_INPUT" ]; then
                    OVERLAYS=("${AUTO_OVERLAYS[@]}")
                else
                    read -ra OVERLAYS <<< "$USER_INPUT"
                fi
                ;;
            *)
                OVERLAYS=("${AUTO_OVERLAYS[@]}")
                ;;
        esac
    fi
fi

[ ${#OVERLAYS[@]} -eq 0 ] && error "No overlays selected"

# Validate overlays exist
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

echo ""
echo -e "  ${BOLD}Final overlays:${NC} ${OVERLAYS[*]}"
echo ""

# ============================================================
# PHASE 3: Backup
# ============================================================

echo -e "${BOLD}=== Phase 3: Backup ===${NC}"
echo ""

BACKUP_DIR=""

if [ "$NO_BACKUP" -eq 1 ]; then
    info "Backup skipped (--no-backup)"
elif [ "$DRY_RUN" -eq 1 ]; then
    dry "create backup directory"
else
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    if [ -n "$CUSTOM_BACKUP_DIR" ]; then
        BACKUP_DIR="$CUSTOM_BACKUP_DIR"
        mkdir -p "$BACKUP_DIR" || error "Cannot create backup directory: $CUSTOM_BACKUP_DIR"
        verbose "Using custom backup directory: $BACKUP_DIR"
    else
        BACKUP_DIR="$TARGET/.claude/.migration-backup/$TIMESTAMP"
        mkdir -p "$BACKUP_DIR"
    fi

    # Backup CLAUDE.md
    if [ -f "$TARGET/CLAUDE.md" ]; then
        cp "$TARGET/CLAUDE.md" "$BACKUP_DIR/CLAUDE.md"
        verbose "Backed up CLAUDE.md ($(wc -c < "$TARGET/CLAUDE.md") bytes)"
        info "Backed up: CLAUDE.md"
    fi

    # Backup .mcp.json
    if [ -f "$TARGET/.mcp.json" ]; then
        cp "$TARGET/.mcp.json" "$BACKUP_DIR/.mcp.json"
        verbose "Backed up .mcp.json ($(wc -c < "$TARGET/.mcp.json") bytes)"
        info "Backed up: .mcp.json"
    fi

    # Backup .claude/ contents (excluding backup dir itself)
    if [ -d "$TARGET/.claude" ]; then
        mkdir -p "$BACKUP_DIR/.claude"
        for item in "$TARGET/.claude"/*; do
            [ -e "$item" ] || continue
            BASENAME=$(basename "$item")
            [ "$BASENAME" = ".migration-backup" ] && continue
            if [ -d "$item" ]; then
                cp -r "$item" "$BACKUP_DIR/.claude/$BASENAME"
                verbose "Backed up directory: .claude/$BASENAME"
            else
                cp "$item" "$BACKUP_DIR/.claude/$BASENAME"
                verbose "Backed up file: .claude/$BASENAME ($(wc -c < "$item") bytes)"
            fi
        done
        info "Backed up: .claude/ contents"
    fi

    if [ -n "$CUSTOM_BACKUP_DIR" ]; then
        info "Backup saved to: $BACKUP_DIR"
    else
        info "Backup saved to: .claude/.migration-backup/$TIMESTAMP"
    fi
fi

# ============================================================
# PHASE 4: Migration
# ============================================================

echo ""
echo -e "${BOLD}=== Phase 4: Migration ===${NC}"
echo ""

# --- Handle already-activated projects ---

if [ "$ALREADY_ACTIVATED" -eq 1 ] && [ "$DRY_RUN" -eq 0 ]; then
    info "Deactivating existing overlay setup..."
    "$SCRIPT_DIR/deactivate.sh" "$TARGET"
    echo ""
fi

# Track created items
CREATED_LINKS=()
CREATED_FILES=()
PRESERVED_CUSTOM=()

# --- Step 1: Create directory structure ---

info "Setting up directory structure..."
for dir in rules skills commands agents hooks; do
    do_mkdir "$TARGET/.claude/$dir"
done

# --- Step 2: Preserve custom rules ---

info "Preserving custom rules..."
if [ -d "$TARGET/.claude/rules" ] && [ "$DRY_RUN" -eq 0 ]; then
    for rule in "$TARGET/.claude/rules"/*.md; do
        [ -f "$rule" ] || continue
        BASENAME=$(basename "$rule")

        # Skip template-prefixed rules and symlinks
        [[ "$BASENAME" == base--* ]] && continue
        [[ "$BASENAME" == custom--* ]] && continue
        [ -L "$rule" ] && continue

        # Check if it looks like an overlay-prefixed rule
        if [[ "$BASENAME" == *--* ]]; then
            PREFIX="${BASENAME%%--*}"
            if [ -d "$OVERLAYS_DIR/$PREFIX" ]; then
                continue  # This is an overlay rule, will be re-created
            fi
        fi

        # This is a custom rule — rename with custom-- prefix
        NEW_NAME="custom--$BASENAME"
        if [ ! -f "$TARGET/.claude/rules/$NEW_NAME" ]; then
            do_mv "$rule" "$TARGET/.claude/rules/$NEW_NAME"
            PRESERVED_CUSTOM+=("rules/$NEW_NAME")
            info "  Preserved: rules/$BASENAME -> rules/$NEW_NAME"
        fi
    done
elif [ "$DRY_RUN" -eq 1 ]; then
    # Show what we'd preserve
    if [ -d "$TARGET/.claude/rules" ]; then
        for rule in "$TARGET/.claude/rules"/*.md; do
            [ -f "$rule" ] || continue
            BASENAME=$(basename "$rule")
            [[ "$BASENAME" == base--* ]] && continue
            [[ "$BASENAME" == custom--* ]] && continue
            [ -L "$rule" ] && continue
            if [[ "$BASENAME" == *--* ]]; then
                PREFIX="${BASENAME%%--*}"
                [ -d "$OVERLAYS_DIR/$PREFIX" ] && continue
            fi
            dry "rename rules/$BASENAME -> rules/custom--$BASENAME"
        done
    fi
fi

# --- Step 3: Symlink base rules ---

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
                do_cp "$rule" "$TARGET/.claude/rules/$DEST_NAME"
                info "  Copied: rules/$DEST_NAME (editable memory file)"
            else
                info "  Skipped: rules/$DEST_NAME (already exists, preserving data)"
            fi
            CREATED_FILES+=(".claude/rules/$DEST_NAME")
        else
            do_ln "$rule" "$TARGET/.claude/rules/$DEST_NAME"
            CREATED_LINKS+=(".claude/rules/$DEST_NAME")
            verbose "Symlink: $rule -> $TARGET/.claude/rules/$DEST_NAME"
            info "  Linked: rules/$DEST_NAME"
        fi
    done
fi

# --- Step 4: Symlink overlay rules ---

info "Linking overlay rules..."
for overlay in "${OVERLAYS[@]}"; do
    if [ -d "$OVERLAYS_DIR/$overlay/rules" ]; then
        for rule in "$OVERLAYS_DIR/$overlay/rules"/*.md; do
            [ -f "$rule" ] || continue
            LINK_NAME="${overlay}--$(basename "$rule")"
            do_ln "$rule" "$TARGET/.claude/rules/$LINK_NAME"
            CREATED_LINKS+=(".claude/rules/$LINK_NAME")
            verbose "Symlink: $rule -> $TARGET/.claude/rules/$LINK_NAME"
            info "  Linked: rules/$LINK_NAME"
        done
    fi
done

# --- Step 5: Preserve custom skills ---

info "Preserving custom skills..."
if [ -d "$TARGET/.claude/skills" ]; then
    for skill_dir in "$TARGET/.claude/skills"/*/; do
        [ -d "$skill_dir" ] || continue
        SKILL_NAME=$(basename "$skill_dir")
        # Skip symlinks (from previous activation)
        [ -L "${skill_dir%/}" ] && continue
        PRESERVED_CUSTOM+=("skills/$SKILL_NAME")
        info "  Preserved: skills/$SKILL_NAME (custom)"
    done
fi

# --- Step 6: Symlink persona skills + overlay skills ---

info "Linking persona skills..."
if [ -d "$PERSONAS_DIR" ]; then
    for persona_dir in "$PERSONAS_DIR"/*/; do
        [ -d "$persona_dir" ] || continue
        persona_name=$(basename "$persona_dir")
        do_ln "$persona_dir" "$TARGET/.claude/skills/$persona_name"
        CREATED_LINKS+=(".claude/skills/$persona_name")
        info "  Linked: skills/$persona_name"
    done
fi

info "Linking overlay skills..."
for overlay in "${OVERLAYS[@]}"; do
    if [ -d "$OVERLAYS_DIR/$overlay/skills" ]; then
        for skill_dir in "$OVERLAYS_DIR/$overlay/skills"/*/; do
            [ -d "$skill_dir" ] || continue
            skill_name=$(basename "$skill_dir")
            do_ln "$skill_dir" "$TARGET/.claude/skills/$skill_name"
            CREATED_LINKS+=(".claude/skills/$skill_name")
            info "  Linked: skills/$skill_name"
        done
    fi
done

# --- Step 7: Preserve custom commands ---

info "Preserving custom commands..."
if [ -d "$TARGET/.claude/commands" ]; then
    for cmd in "$TARGET/.claude/commands"/*.md; do
        [ -f "$cmd" ] || continue
        [ -L "$cmd" ] && continue  # Skip symlinks
        PRESERVED_CUSTOM+=("commands/$(basename "$cmd")")
        info "  Preserved: commands/$(basename "$cmd") (custom)"
    done
fi

# --- Step 8: Symlink overlay commands + agents ---

info "Linking overlay commands..."
for overlay in "${OVERLAYS[@]}"; do
    if [ -d "$OVERLAYS_DIR/$overlay/commands" ]; then
        for cmd in "$OVERLAYS_DIR/$overlay/commands"/*.md; do
            [ -f "$cmd" ] || continue
            CMD_NAME=$(basename "$cmd")
            # Don't overwrite custom commands
            if [ -f "$TARGET/.claude/commands/$CMD_NAME" ] && [ ! -L "$TARGET/.claude/commands/$CMD_NAME" ]; then
                warn "Skipping overlay command $CMD_NAME (custom version exists)"
                continue
            fi
            do_ln "$cmd" "$TARGET/.claude/commands/$CMD_NAME"
            CREATED_LINKS+=(".claude/commands/$CMD_NAME")
            info "  Linked: commands/$CMD_NAME"
        done
    fi
done

info "Linking agents..."
if [ -d "$AGENTS_DIR" ]; then
    for agent in "$AGENTS_DIR"/*.md; do
        [ -f "$agent" ] || continue
        do_ln "$agent" "$TARGET/.claude/agents/$(basename "$agent")"
        CREATED_LINKS+=(".claude/agents/$(basename "$agent")")
        info "  Linked: agents/$(basename "$agent")"
    done
fi

# --- Step 9: Merge MCP configs ---

info "Merging MCP configurations..."
MCP_FILES=()
MCP_BASE_ARG=()

# Existing .mcp.json as the base (so custom servers are preserved)
if [ -f "$TARGET/.mcp.json" ] && [ "$DRY_RUN" -eq 0 ]; then
    if [ -n "$BACKUP_DIR" ] && [ -f "$BACKUP_DIR/.mcp.json" ]; then
        MCP_BASE_ARG=("--base" "$BACKUP_DIR/.mcp.json")
        verbose "Using backed-up .mcp.json as base for merge"
    else
        MCP_BASE_ARG=("--base" "$TARGET/.mcp.json")
        verbose "Using existing .mcp.json as base for merge"
    fi
fi

# Overlay MCP configs on top
for overlay in "${OVERLAYS[@]}"; do
    MCP="$OVERLAYS_DIR/$overlay/mcp.json"
    [ -f "$MCP" ] && MCP_FILES+=("$MCP")
done

if [ ${#MCP_FILES[@]} -gt 0 ] || [ ${#MCP_BASE_ARG[@]} -gt 0 ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
        dry "merge ${#MCP_FILES[@]} MCP config(s) -> .mcp.json"
    else
        if [ ${#MCP_FILES[@]} -gt 0 ]; then
            verbose "Merging MCP files: ${MCP_FILES[*]}"
            python3 "$SCRIPTS_DIR/merge-configs.py" --type mcp --output "$TARGET/.mcp.json" "${MCP_BASE_ARG[@]+"${MCP_BASE_ARG[@]}"}" "${MCP_FILES[@]}"
        elif [ ${#MCP_BASE_ARG[@]} -gt 0 ]; then
            verbose "No overlay MCP configs; preserving existing .mcp.json as-is"
        fi
    fi
    CREATED_FILES+=(".mcp.json")
    info "  Generated: .mcp.json"
fi

# --- Step 10: Merge settings ---

info "Merging settings..."
SETTINGS_FILES=()
SETTINGS_BASE_ARG=()

# Existing settings as base
if [ -f "$TARGET/.claude/settings.json" ] && [ "$DRY_RUN" -eq 0 ]; then
    if [ -n "$BACKUP_DIR" ] && [ -f "$BACKUP_DIR/.claude/settings.json" ]; then
        SETTINGS_BASE_ARG=("--base" "$BACKUP_DIR/.claude/settings.json")
        verbose "Using backed-up settings.json as base for merge"
    else
        SETTINGS_BASE_ARG=("--base" "$TARGET/.claude/settings.json")
        verbose "Using existing settings.json as base for merge"
    fi
fi

# Base + overlay settings on top
SETTINGS_FILES+=("$BASE_DIR/settings.json")
for overlay in "${OVERLAYS[@]}"; do
    SETTINGS="$OVERLAYS_DIR/$overlay/settings.json"
    [ -f "$SETTINGS" ] && SETTINGS_FILES+=("$SETTINGS")
done

if [ "$DRY_RUN" -eq 1 ]; then
    dry "merge ${#SETTINGS_FILES[@]} settings file(s) -> .claude/settings.json"
else
    verbose "Merging settings files: ${SETTINGS_FILES[*]}"
    python3 "$SCRIPTS_DIR/merge-configs.py" --type settings --output "$TARGET/.claude/settings.json" "${SETTINGS_BASE_ARG[@]+"${SETTINGS_BASE_ARG[@]}"}" "${SETTINGS_FILES[@]}"
fi
CREATED_FILES+=(".claude/settings.json")
info "  Generated: .claude/settings.json"

# --- Step 11: Merge CLAUDE.md ---

info "Generating CLAUDE.md..."
if [ "$DRY_RUN" -eq 1 ]; then
    if [ -f "$TARGET/CLAUDE.md" ]; then
        dry "merge base CLAUDE.md with existing CLAUDE.md"
    else
        dry "copy base CLAUDE.md"
    fi
else
    MERGE_ARGS=("--base" "$BASE_DIR/CLAUDE.md" "--output" "$TARGET/CLAUDE.md")
    if [ -f "$TARGET/CLAUDE.md" ]; then
        # Use backed-up version for existing content
        if [ -n "$BACKUP_DIR" ] && [ -f "$BACKUP_DIR/CLAUDE.md" ]; then
            MERGE_ARGS+=("--existing" "$BACKUP_DIR/CLAUDE.md")
        else
            # Merge with current (we already read it above)
            MERGE_ARGS+=("--existing" "$TARGET/CLAUDE.md")
        fi
    fi
    python3 "$SCRIPTS_DIR/merge-claude-md.py" "${MERGE_ARGS[@]}"
fi
CREATED_FILES+=("CLAUDE.md")
info "  Generated: CLAUDE.md"

# --- Step 12: Copy hooks ---

info "Copying hooks..."
if [ -d "$BASE_DIR/hooks" ]; then
    for hook in "$BASE_DIR/hooks"/*; do
        [ -f "$hook" ] || continue
        HOOK_NAME=$(basename "$hook")
        DEST="$TARGET/.claude/hooks/$HOOK_NAME"

        if [ -f "$DEST" ] && [ "$DRY_RUN" -eq 0 ]; then
            # Existing hook with same name — rename existing with custom- prefix
            CUSTOM_DEST="$TARGET/.claude/hooks/custom-$HOOK_NAME"
            if [ ! -f "$CUSTOM_DEST" ]; then
                mv "$DEST" "$CUSTOM_DEST"
                PRESERVED_CUSTOM+=("hooks/custom-$HOOK_NAME")
                info "  Preserved: hooks/$HOOK_NAME -> hooks/custom-$HOOK_NAME"
            fi
        fi

        do_cp "$hook" "$DEST"
        if [ "$DRY_RUN" -eq 0 ]; then
            chmod +x "$DEST"
        fi
        CREATED_FILES+=(".claude/hooks/$HOOK_NAME")
        info "  Copied: hooks/$HOOK_NAME"
    done
fi

# --- Step 13: Record activation state ---

info "Recording migration state..."
if [ "$DRY_RUN" -eq 1 ]; then
    dry "write .claude/.activated-overlays.json"
    dry "write .claude/.migration-state.json"
else
    # Determine detection mode
    DETECTION_MODE="interactive"
    [ "$AUTO_MODE" -eq 1 ] && DETECTION_MODE="auto"
    [ ${#MANUAL_OVERLAYS[@]} -gt 0 ] && DETECTION_MODE="manual"
    [ -n "$COMPOSITION" ] && DETECTION_MODE="composition"

    python3 << PYEOF
import json
from datetime import datetime, timezone

# Build arrays from bash
overlays = [$(printf '"%s",' "${OVERLAYS[@]}")]
created_links = [$(printf '"%s",' "${CREATED_LINKS[@]+"${CREATED_LINKS[@]}"}")]
created_files = [$(printf '"%s",' "${CREATED_FILES[@]+"${CREATED_FILES[@]}"}")]
preserved_custom = [$(printf '"%s",' "${PRESERVED_CUSTOM[@]+"${PRESERVED_CUSTOM[@]}"}")]

# Clean trailing empty strings from printf
overlays = [o for o in overlays if o]
created_links = [l for l in created_links if l]
created_files = [f for f in created_files if f]
preserved_custom = [p for p in preserved_custom if p]

# Write .activated-overlays.json (for deactivate.sh compatibility)
state = {
    "overlays": overlays,
    "created_links": created_links,
    "created_files": created_files,
    "preserved_custom": preserved_custom,
    "template_dir": "$SCRIPT_DIR",
    "migrated": True,
    "backup_dir": "$([ -n "$BACKUP_DIR" ] && echo "$BACKUP_DIR" || echo "")"
}

with open("$TARGET/.claude/.activated-overlays.json", "w") as f:
    json.dump(state, f, indent=2)
    f.write("\n")

# Write .migration-state.json (migration-specific metadata)
migration_state = {
    "migrated_at": datetime.now(timezone.utc).isoformat(),
    "overlays": overlays,
    "backup_dir": "$([ -n "$BACKUP_DIR" ] && echo "$BACKUP_DIR" || echo "")",
    "preserved_custom": preserved_custom,
    "detection_mode": "$DETECTION_MODE",
    "template_dir": "$SCRIPT_DIR"
}

with open("$TARGET/.claude/.migration-state.json", "w") as f:
    json.dump(migration_state, f, indent=2)
    f.write("\n")
PYEOF
    info "  Saved: .claude/.activated-overlays.json"
    info "  Saved: .claude/.migration-state.json"
fi

# ============================================================
# PHASE 5: Report
# ============================================================

echo ""
echo "============================================"
echo -e "${BOLD}Migration Report${NC}"
echo "============================================"
echo ""
echo "  Target:     $TARGET"
echo "  Overlays:   ${OVERLAYS[*]}"
if [ -n "$BACKUP_DIR" ]; then
    echo "  Backup:     .claude/.migration-backup/$(basename "$BACKUP_DIR")"
fi
echo ""

if [ "$DRY_RUN" -eq 1 ]; then
    echo -e "  ${CYAN}DRY RUN — no changes were made${NC}"
    echo ""
else
    # Count items
    RULE_COUNT=$(ls "$TARGET/.claude/rules/" 2>/dev/null | wc -l)
    SKILL_COUNT=$(ls "$TARGET/.claude/skills/" 2>/dev/null | wc -l)
    CMD_COUNT=$(ls "$TARGET/.claude/commands/" 2>/dev/null | wc -l)
    AGENT_COUNT=$(ls "$TARGET/.claude/agents/" 2>/dev/null | wc -l)

    echo "  Added:"
    echo "    Rules:    $RULE_COUNT files"
    echo "    Skills:   $SKILL_COUNT directories"
    echo "    Commands: $CMD_COUNT files"
    echo "    Agents:   $AGENT_COUNT files"
    echo ""

    if [ "${#PRESERVED_CUSTOM[@]}" -gt 0 ] 2>/dev/null; then
        echo "  Preserved custom items:"
        for item in "${PRESERVED_CUSTOM[@]}"; do
            echo "    - $item"
        done
        echo ""
    fi

    echo "  To deactivate: $(dirname "$0")/deactivate.sh $TARGET"
    if [ -n "$BACKUP_DIR" ]; then
        echo "  To restore backup: cp -r $BACKUP_DIR/* $TARGET/"
    fi
fi

echo "============================================"
echo ""
