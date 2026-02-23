#!/usr/bin/env bash
# detect-project.sh — Analyze an existing project and recommend overlays.
#
# Outputs a JSON report to stdout with detected languages, frameworks,
# recommended overlays, and existing Claude Code configuration.
#
# Usage: ./detect-project.sh <project-path>
# Example: ./detect-project.sh ~/my-app

set -euo pipefail

TARGET="${1:?Usage: detect-project.sh <project-path>}"
TARGET="$(cd "$TARGET" 2>/dev/null && pwd)" || { echo '{"error":"Directory not found"}'; exit 1; }

# --- Accumulators ---

LANGUAGES=()
FRAMEWORKS=()
OVERLAYS=()
SIGNALS_JSON="{}"  # Built up as JSON object

add_language() {
    local lang="$1"
    for l in "${LANGUAGES[@]:-}"; do [ "$l" = "$lang" ] && return; done
    LANGUAGES+=("$lang")
}

add_framework() {
    local fw="$1"
    for f in "${FRAMEWORKS[@]:-}"; do [ "$f" = "$fw" ] && return; done
    FRAMEWORKS+=("$fw")
}

add_overlay() {
    local overlay="$1" signal="$2"
    local found=0
    for o in "${OVERLAYS[@]:-}"; do [ "$o" = "$overlay" ] && found=1 && break; done
    [ "$found" -eq 0 ] && OVERLAYS+=("$overlay")
    # Accumulate signals
    SIGNALS_JSON=$(python3 -c "
import json, sys
signals = json.loads(sys.argv[1])
overlay = sys.argv[2]
signal = sys.argv[3]
signals.setdefault(overlay, []).append(signal)
print(json.dumps(signals))
" "$SIGNALS_JSON" "$overlay" "$signal")
}

# --- Parse existing MCP servers (reused across detections) ---

EXISTING_MCP_SERVERS_LIST=""
if [ -f "$TARGET/.mcp.json" ]; then
    EXISTING_MCP_SERVERS_LIST=$(python3 -c "
import json
data = json.load(open('$TARGET/.mcp.json'))
for name in data.get('mcpServers', {}):
    print(name)
" 2>/dev/null || true)
fi

has_mcp_server() {
    echo "$EXISTING_MCP_SERVERS_LIST" | grep -qiF "$1" 2>/dev/null
}

# --- Language & Framework Detection ---

# JavaScript / TypeScript
if [ -f "$TARGET/package.json" ]; then
    add_language "javascript"
    [ -f "$TARGET/tsconfig.json" ] && add_language "typescript"

    # Read package.json deps
    DEPS=$(python3 -c "
import json
data = json.load(open('$TARGET/package.json'))
deps = {}
deps.update(data.get('dependencies', {}))
deps.update(data.get('devDependencies', {}))
for name, ver in sorted(deps.items()):
    print(f'{name}@{ver}')
" 2>/dev/null || true)

    # Web framework detection
    if echo "$DEPS" | grep -qE '^(react|next|@next/)'; then
        add_framework "react"
        echo "$DEPS" | grep -q '^next@' && add_framework "next.js"
        add_overlay "web-dev" "package.json: React/Next.js dependencies"
    fi
    if echo "$DEPS" | grep -qE '^(vue|nuxt|@vue/)'; then
        add_framework "vue"
        add_overlay "web-dev" "package.json: Vue/Nuxt dependencies"
    fi
    if echo "$DEPS" | grep -qE '^(@angular/core)'; then
        add_framework "angular"
        add_overlay "web-dev" "package.json: Angular dependencies"
    fi
    if echo "$DEPS" | grep -qE '^(svelte|@sveltejs/)'; then
        add_framework "svelte"
        add_overlay "web-dev" "package.json: Svelte dependencies"
    fi

    # Test framework detection
    if echo "$DEPS" | grep -qE '^(jest|vitest|@testing-library|mocha|cypress|playwright)'; then
        add_overlay "quality-assurance" "package.json: test framework dependencies"
    fi
fi

# Next.js / web config files
[ -f "$TARGET/next.config.js" ] || [ -f "$TARGET/next.config.mjs" ] || [ -f "$TARGET/next.config.ts" ] && {
    add_overlay "web-dev" "next.config found"
}
[ -f "$TARGET/vite.config.ts" ] || [ -f "$TARGET/vite.config.js" ] && {
    add_overlay "web-dev" "vite.config found"
}
[ -f "$TARGET/webpack.config.js" ] && {
    add_overlay "web-dev" "webpack.config.js found"
}

# Python
if [ -f "$TARGET/requirements.txt" ] || [ -f "$TARGET/pyproject.toml" ] || [ -f "$TARGET/setup.py" ] || [ -f "$TARGET/Pipfile" ]; then
    add_language "python"

    # Check for ML/AI libraries
    ML_SIGNAL=""
    for pyfile in "$TARGET/requirements.txt" "$TARGET/pyproject.toml" "$TARGET/setup.py" "$TARGET/Pipfile"; do
        [ -f "$pyfile" ] || continue
        if grep -qiE '(torch|tensorflow|keras|scikit-learn|sklearn|transformers|huggingface|jax|flax|wandb|mlflow)' "$pyfile" 2>/dev/null; then
            ML_SIGNAL="$pyfile: ML/AI library dependencies"
            break
        fi
    done
    [ -n "$ML_SIGNAL" ] && add_overlay "ai-research" "$ML_SIGNAL"

    # Check for test configs
    if [ -f "$TARGET/pytest.ini" ] || [ -f "$TARGET/setup.cfg" ] && grep -q '\[tool:pytest\]' "$TARGET/setup.cfg" 2>/dev/null; then
        add_overlay "quality-assurance" "pytest configuration found"
    fi
    if [ -f "$TARGET/pyproject.toml" ] && grep -q '\[tool.pytest' "$TARGET/pyproject.toml" 2>/dev/null; then
        add_overlay "quality-assurance" "pytest configuration in pyproject.toml"
    fi
fi

# Kotlin / Android
if [ -f "$TARGET/build.gradle" ] || [ -f "$TARGET/build.gradle.kts" ]; then
    add_language "kotlin"
    for gradle_file in "$TARGET/build.gradle" "$TARGET/build.gradle.kts" "$TARGET/app/build.gradle" "$TARGET/app/build.gradle.kts"; do
        [ -f "$gradle_file" ] || continue
        if grep -qE '(com\.android|android\s*\{|applicationId)' "$gradle_file" 2>/dev/null; then
            add_framework "android"
            add_overlay "android-dev" "Android Gradle plugin detected"
            break
        fi
    done
fi
[ -f "$TARGET/AndroidManifest.xml" ] || [ -f "$TARGET/app/src/main/AndroidManifest.xml" ] && {
    add_overlay "android-dev" "AndroidManifest.xml found"
}

# Godot
if [ -f "$TARGET/project.godot" ]; then
    add_language "gdscript"
    add_framework "godot"
    add_overlay "gamedev" "project.godot found"
fi
if compgen -G "$TARGET/*.gd" > /dev/null 2>&1; then
    add_overlay "gamedev" "GDScript files found"
fi

# Unity
if [ -d "$TARGET/Assets" ] && [ -f "$TARGET/ProjectSettings/ProjectVersion.txt" ]; then
    add_language "csharp"
    add_framework "unity"
    add_overlay "gamedev" "Unity project structure detected"
fi

# Blender files
if compgen -G "$TARGET/*.blend" > /dev/null 2>&1 || compgen -G "$TARGET/**/*.blend" > /dev/null 2>&1; then
    add_overlay "gamedev" "Blender files found"
fi

# Rust
[ -f "$TARGET/Cargo.toml" ] && add_language "rust"

# Go
[ -f "$TARGET/go.mod" ] && add_language "go"

# Java
if compgen -G "$TARGET/src/**/*.java" > /dev/null 2>&1; then
    add_language "java"
fi

# Jupyter notebooks with ML
if compgen -G "$TARGET/*.ipynb" > /dev/null 2>&1 || compgen -G "$TARGET/**/*.ipynb" > /dev/null 2>&1; then
    # Check if notebooks contain ML imports
    if grep -rlE '(import torch|import tensorflow|from sklearn|import transformers|import keras)' "$TARGET"/*.ipynb "$TARGET"/**/*.ipynb 2>/dev/null | head -1 | grep -q .; then
        add_overlay "ai-research" "Jupyter notebooks with ML imports"
    fi
fi

# Obsidian vault
if [ -d "$TARGET/.obsidian" ]; then
    add_framework "obsidian"
    add_overlay "knowledge-management" ".obsidian/ directory found"
fi

# MediaWiki
if [ -f "$TARGET/LocalSettings.php" ]; then
    add_framework "mediawiki"
    add_overlay "wiki-management" "LocalSettings.php found"
fi

# Test directories (generic)
for test_dir in "$TARGET/test" "$TARGET/tests" "$TARGET/__tests__" "$TARGET/spec"; do
    if [ -d "$test_dir" ]; then
        add_overlay "quality-assurance" "$(basename "$test_dir")/ directory found"
        break
    fi
done

# Jest / Vitest / Mocha configs
for test_cfg in "$TARGET/jest.config.js" "$TARGET/jest.config.ts" "$TARGET/vitest.config.ts" "$TARGET/vitest.config.js" "$TARGET/.mocharc.yml"; do
    if [ -f "$test_cfg" ]; then
        add_overlay "quality-assurance" "$(basename "$test_cfg") found"
        break
    fi
done

# --- MCP-based signals for existing overlays ---

# web-dev: playwright in MCP
has_mcp_server "playwright" && add_overlay "web-dev" "playwright MCP server in .mcp.json"

# web-dev: ESLint config files
for eslint_cfg in "$TARGET/.eslintrc" "$TARGET/.eslintrc.js" "$TARGET/.eslintrc.json" "$TARGET/.eslintrc.yml" "$TARGET/eslint.config.js" "$TARGET/eslint.config.mjs"; do
    if [ -f "$eslint_cfg" ]; then
        add_overlay "web-dev" "$(basename "$eslint_cfg") found"
        break
    fi
done

# ai-research: experiment tracking directories
for ml_dir in "$TARGET/wandb" "$TARGET/mlruns" "$TARGET/experiments"; do
    if [ -d "$ml_dir" ]; then
        add_overlay "ai-research" "$(basename "$ml_dir")/ directory found"
        break
    fi
done

# ai-research: conda environment with ML packages
if [ -f "$TARGET/environment.yml" ]; then
    if grep -qiE '(torch|tensorflow|keras|scikit-learn|sklearn|transformers|jax)' "$TARGET/environment.yml" 2>/dev/null; then
        add_overlay "ai-research" "environment.yml with ML packages"
    fi
fi

# ai-research: MCP servers
has_mcp_server "huggingface" && add_overlay "ai-research" "huggingface MCP server in .mcp.json"

# gamedev: GDScript files in scripts/ subdirectory (Godot convention)
if compgen -G "$TARGET/scripts/*.gd" > /dev/null 2>&1; then
    add_overlay "gamedev" "GDScript files in scripts/ directory"
fi

# gamedev: MCP servers
has_mcp_server "gdai-mcp" && add_overlay "gamedev" "gdai-mcp server in .mcp.json"
has_mcp_server "unity-mcp" && add_overlay "gamedev" "unity-mcp server in .mcp.json"
has_mcp_server "blender-mcp" && add_overlay "gamedev" "blender-mcp server in .mcp.json"

# quality-assurance: CI config files
if [ -d "$TARGET/.github/workflows" ]; then
    add_overlay "quality-assurance" ".github/workflows/ directory found"
fi
[ -f "$TARGET/Jenkinsfile" ] && add_overlay "quality-assurance" "Jenkinsfile found"
[ -d "$TARGET/.circleci" ] && add_overlay "quality-assurance" ".circleci/ directory found"

# --- New overlay detections ---

# research: search-oriented MCP servers
has_mcp_server "brave-search" && add_overlay "research" "brave-search MCP server in .mcp.json"
has_mcp_server "exa" && add_overlay "research" "exa MCP server in .mcp.json"

# worldbuilding: characteristic directories
for wb_dir in "$TARGET/lore" "$TARGET/worldbuilding" "$TARGET/world"; do
    if [ -d "$wb_dir" ]; then
        add_overlay "worldbuilding" "$(basename "$wb_dir")/ directory found"
    fi
done

# worldbuilding: combination of memory + obsidian + mediawiki MCP servers
if has_mcp_server "memory" && has_mcp_server "obsidian" && has_mcp_server "mediawiki"; then
    add_overlay "worldbuilding" "memory + obsidian + mediawiki MCP servers detected"
fi

# wiki-management: MCP server
has_mcp_server "mediawiki" && add_overlay "wiki-management" "mediawiki MCP server in .mcp.json"

# uxr: characteristic directories
for uxr_dir in "$TARGET/research" "$TARGET/studies" "$TARGET/uxr"; do
    if [ -d "$uxr_dir" ]; then
        add_overlay "uxr" "$(basename "$uxr_dir")/ directory found"
    fi
done

# knowledge-management: MCP server
has_mcp_server "obsidian" && add_overlay "knowledge-management" "obsidian MCP server in .mcp.json"

# --- Detect Existing Claude Config ---

HAS_CLAUDE_MD=False
HAS_CLAUDE_DIR=False
HAS_MCP_JSON=False
HAS_SETTINGS=False
CUSTOM_RULES="[]"
CUSTOM_SKILLS="[]"
CUSTOM_HOOKS="[]"
EXISTING_MCP_SERVERS="[]"

[ -f "$TARGET/CLAUDE.md" ] && HAS_CLAUDE_MD=True
[ -d "$TARGET/.claude" ] && HAS_CLAUDE_DIR=True
[ -f "$TARGET/.mcp.json" ] && HAS_MCP_JSON=True
[ -f "$TARGET/.claude/settings.json" ] && HAS_SETTINGS=True

# Find custom rules (not template-prefixed)
if [ -d "$TARGET/.claude/rules" ]; then
    CUSTOM_RULES=$(python3 -c "
import os, json
rules = []
rules_dir = '$TARGET/.claude/rules'
if os.path.isdir(rules_dir):
    for f in sorted(os.listdir(rules_dir)):
        if f.endswith('.md') and not f.startswith(('base--', 'custom--')):
            # Check if it looks like an overlay-prefixed file
            parts = f.split('--', 1)
            if len(parts) == 1:
                rules.append(f)
print(json.dumps(rules))
")
fi

# Find custom skills
if [ -d "$TARGET/.claude/skills" ]; then
    CUSTOM_SKILLS=$(python3 -c "
import os, json
skills = []
skills_dir = '$TARGET/.claude/skills'
if os.path.isdir(skills_dir):
    for d in sorted(os.listdir(skills_dir)):
        if os.path.isdir(os.path.join(skills_dir, d)) and not os.path.islink(os.path.join(skills_dir, d)):
            skills.append(d)
print(json.dumps(skills))
")
fi

# Find custom hooks
if [ -d "$TARGET/.claude/hooks" ]; then
    CUSTOM_HOOKS=$(python3 -c "
import os, json
hooks = []
hooks_dir = '$TARGET/.claude/hooks'
if os.path.isdir(hooks_dir):
    for f in sorted(os.listdir(hooks_dir)):
        if os.path.isfile(os.path.join(hooks_dir, f)):
            hooks.append(f)
print(json.dumps(hooks))
")
fi

# Find existing MCP servers
if [ -f "$TARGET/.mcp.json" ]; then
    EXISTING_MCP_SERVERS=$(python3 -c "
import json
data = json.load(open('$TARGET/.mcp.json'))
servers = list(data.get('mcpServers', {}).keys())
print(json.dumps(sorted(servers)))
" 2>/dev/null || echo "[]")
fi

# --- Match to composition ---

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$SCRIPT_DIR/../manifest.json"

RECOMMENDED_COMPOSITION="None"
if [ ${#OVERLAYS[@]} -gt 0 ]; then
    OVERLAY_LIST=$(printf '%s\n' "${OVERLAYS[@]}" | sort | tr '\n' ',' | sed 's/,$//')
    RECOMMENDED_COMPOSITION=$(python3 << PYEOF
import json
manifest = json.load(open('$MANIFEST'))
overlays = set('$OVERLAY_LIST'.split(','))
for name, comp in manifest.get('compositions', {}).items():
    if set(comp['overlays']) == overlays:
        print(repr(name))
        exit(0)
    if set(comp['overlays']).issubset(overlays) and len(comp['overlays']) >= 2:
        print(repr(name))
        exit(0)
print('None')
PYEOF
)
fi

# --- Build arrays as JSON strings ---

json_array_from_bash() {
    local arr=("$@")
    if [ ${#arr[@]} -eq 0 ]; then
        echo "[]"
        return
    fi
    printf '%s\n' "${arr[@]}" | python3 -c "import sys,json; print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))"
}

LANGUAGES_JSON=$(json_array_from_bash "${LANGUAGES[@]+"${LANGUAGES[@]}"}")
FRAMEWORKS_JSON=$(json_array_from_bash "${FRAMEWORKS[@]+"${FRAMEWORKS[@]}"}")
OVERLAYS_JSON=$(json_array_from_bash "${OVERLAYS[@]+"${OVERLAYS[@]}"}")

# --- Output JSON report ---

python3 << PYEOF
import json

report = {
    "languages": $LANGUAGES_JSON,
    "frameworks": $FRAMEWORKS_JSON,
    "recommended_overlays": $OVERLAYS_JSON,
    "recommended_composition": $RECOMMENDED_COMPOSITION,
    "existing_claude_config": {
        "has_claude_md": $HAS_CLAUDE_MD,
        "has_claude_dir": $HAS_CLAUDE_DIR,
        "has_mcp_json": $HAS_MCP_JSON,
        "has_settings": $HAS_SETTINGS,
        "custom_rules": $CUSTOM_RULES,
        "custom_skills": $CUSTOM_SKILLS,
        "custom_hooks": $CUSTOM_HOOKS,
        "existing_mcp_servers": $EXISTING_MCP_SERVERS
    },
    "signals": $SIGNALS_JSON
}

print(json.dumps(report, indent=2))
PYEOF
