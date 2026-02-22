#!/usr/bin/env bash
# Validate an overlay directory for correctness.
# Checks: overlay.json schema, rule file paths, skill structure, conflict detection.
#
# Usage: ./validate-overlay.sh <overlay-directory> [manifest.json]
# Example: ./validate-overlay.sh overlays/web-dev manifest.json

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ERRORS=0
WARNINGS=0

error() { echo -e "${RED}ERROR:${NC} $1"; ((ERRORS++)); }
warn() { echo -e "${YELLOW}WARN:${NC} $1"; ((WARNINGS++)); }
ok() { echo -e "${GREEN}OK:${NC} $1"; }

OVERLAY_DIR="${1:?Usage: validate-overlay.sh <overlay-directory> [manifest.json]}"
MANIFEST="${2:-}"

if [ ! -d "$OVERLAY_DIR" ]; then
    error "Directory not found: $OVERLAY_DIR"
    exit 1
fi

OVERLAY_NAME=$(basename "$OVERLAY_DIR")
echo "Validating overlay: $OVERLAY_NAME"
echo "================================="

# 1. Check overlay.json exists and is valid JSON
OVERLAY_JSON="$OVERLAY_DIR/overlay.json"
if [ ! -f "$OVERLAY_JSON" ]; then
    error "Missing overlay.json"
else
    if python3 -c "import json; json.load(open('$OVERLAY_JSON'))" 2>/dev/null; then
        ok "overlay.json is valid JSON"

        # Check required fields
        for field in name description conflicts depends; do
            if python3 -c "import json; d=json.load(open('$OVERLAY_JSON')); assert '$field' in d" 2>/dev/null; then
                ok "overlay.json has '$field' field"
            else
                error "overlay.json missing required field: $field"
            fi
        done

        # Check name matches directory
        DECLARED_NAME=$(python3 -c "import json; print(json.load(open('$OVERLAY_JSON'))['name'])" 2>/dev/null)
        if [ "$DECLARED_NAME" = "$OVERLAY_NAME" ]; then
            ok "overlay.json name matches directory name"
        else
            error "overlay.json name '$DECLARED_NAME' does not match directory '$OVERLAY_NAME'"
        fi
    else
        error "overlay.json is not valid JSON"
    fi
fi

# 2. Check rules have YAML frontmatter with paths
if [ -d "$OVERLAY_DIR/rules" ]; then
    for rule_file in "$OVERLAY_DIR/rules"/*.md; do
        [ -f "$rule_file" ] || continue
        rule_name=$(basename "$rule_file")
        if head -1 "$rule_file" | grep -q "^---"; then
            ok "Rule $rule_name has YAML frontmatter"
            # Check for paths field
            if grep -q "^paths:" "$rule_file" || grep -q "^  - " "$rule_file"; then
                ok "Rule $rule_name has path scoping"
            else
                warn "Rule $rule_name has frontmatter but no paths: field (will load globally)"
            fi
        else
            warn "Rule $rule_name missing YAML frontmatter (will load globally)"
        fi

        # Check line count
        LINE_COUNT=$(wc -l < "$rule_file")
        if [ "$LINE_COUNT" -gt 30 ]; then
            warn "Rule $rule_name is $LINE_COUNT lines (recommended: 15-30)"
        else
            ok "Rule $rule_name is $LINE_COUNT lines"
        fi
    done
else
    warn "No rules directory found"
fi

# 3. Check skills have SKILL.md with frontmatter
if [ -d "$OVERLAY_DIR/skills" ]; then
    for skill_dir in "$OVERLAY_DIR/skills"/*/; do
        [ -d "$skill_dir" ] || continue
        skill_name=$(basename "$skill_dir")
        skill_file="$skill_dir/SKILL.md"
        if [ -f "$skill_file" ]; then
            ok "Skill $skill_name has SKILL.md"
            if head -1 "$skill_file" | grep -q "^---"; then
                ok "Skill $skill_name has frontmatter"
                # Check for name and description
                if grep -q "^name:" "$skill_file"; then
                    ok "Skill $skill_name has name field"
                else
                    error "Skill $skill_name missing name field in frontmatter"
                fi
                if grep -q "^description:" "$skill_file"; then
                    ok "Skill $skill_name has description field"
                else
                    error "Skill $skill_name missing description field in frontmatter"
                fi
            else
                error "Skill $skill_name SKILL.md missing frontmatter"
            fi
        else
            error "Skill $skill_name missing SKILL.md"
        fi
    done
else
    warn "No skills directory found"
fi

# 4. Check mcp.json if present
MCP_JSON="$OVERLAY_DIR/mcp.json"
if [ -f "$MCP_JSON" ]; then
    if python3 -c "import json; json.load(open('$MCP_JSON'))" 2>/dev/null; then
        ok "mcp.json is valid JSON"

        # Check for hardcoded secrets
        if grep -Pq '(sk-|ghp_|AKIA|xox[baprs]-)' "$MCP_JSON" 2>/dev/null; then
            error "mcp.json contains hardcoded secrets! Use \${ENV_VAR} syntax."
        else
            ok "mcp.json has no hardcoded secrets"
        fi

        # Check env vars use ${} syntax
        if grep -q '"env"' "$MCP_JSON"; then
            if grep -Pq '"[A-Z_]+"\s*:\s*"\$\{' "$MCP_JSON" 2>/dev/null; then
                ok "mcp.json uses \${ENV_VAR} for environment variables"
            fi
        fi
    else
        error "mcp.json is not valid JSON"
    fi
fi

# 5. Check for conflicts with manifest
if [ -n "$MANIFEST" ] && [ -f "$MANIFEST" ]; then
    echo ""
    echo "Checking manifest consistency..."
    if python3 -c "
import json
manifest = json.load(open('$MANIFEST'))
if '$OVERLAY_NAME' in manifest.get('overlays', {}):
    print('Found in manifest')
else:
    print('NOT in manifest')
    exit(1)
" 2>/dev/null; then
        ok "Overlay registered in manifest.json"
    else
        warn "Overlay not found in manifest.json"
    fi
fi

# Summary
echo ""
echo "================================="
echo "Validation complete: $ERRORS error(s), $WARNINGS warning(s)"
if [ "$ERRORS" -gt 0 ]; then
    echo -e "${RED}FAILED${NC}"
    exit 1
else
    echo -e "${GREEN}PASSED${NC}"
    exit 0
fi
