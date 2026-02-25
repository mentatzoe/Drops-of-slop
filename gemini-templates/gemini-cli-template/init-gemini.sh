#!/usr/bin/env bash

# Gemini CLI Template Initializer
# Downloads and installs the Gemini CLI Gold Standard Template into the current directory.
# Features a safe, LLM-driven migration path for existing setups.

set -e

REPO_URL="https://github.com/mentatzoe/Drops-of-slop.git"
TEMPLATE_PATH="gemini-templates/gemini-cli-template"

echo "💎 Initializing Gemini CLI Workspace..."
echo "🔍 Checking prerequisites..."

for cmd in node npx sqlite3 jq; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "❌ Error: '$cmd' is not installed. Please install it before proceeding."
        exit 1
    fi
done
echo "  ✅ Prerequisites met."

is_migration=false
DRY_RUN=${DRY_RUN:-false}

# Parse command-line args for dry-run
for arg in "$@"; do
    if [[ "$arg" == "--dry-run" || "$arg" == "-d" ]]; then
        DRY_RUN=true
        echo "🔍 DRY-RUN MODE ACTIVATED: No files will be modified in your workspace."
    fi
done

# 1. Detect existing setup and ask for Migration
if [ -d ".gemini" ] || [ -d ".agents" ] || [ -f "GEMINI.md" ]; then
    echo "⚠️  Existing Gemini configuration detected."
    if [ "$DRY_RUN" = true ]; then
        echo "💡 [Dry-Run] Would prompt for migration."
        is_migration=true
    else
        read -p "Do you want to safely migrate your existing setup to the Gold Standard architecture? [y/N] " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            is_migration=true
            TIMESTAMP=$(date +%s)
            echo "📦 Creating backups..."
            [ -d ".gemini" ] && cp -R .gemini ".gemini.backup_${TIMESTAMP}"
            [ -d ".agents" ] && cp -R .agents ".agents.backup_${TIMESTAMP}"
            [ -f "GEMINI.md" ] && cp GEMINI.md "GEMINI.backup_${TIMESTAMP}.md"
        else
            echo "Aborting initialization to protect existing files."
            exit 1
        fi
    fi
fi

# 2. Fetch template via sparse-checkout
echo "📥 Fetching template from $REPO_URL..."
TMP_DIR=$(mktemp -d)

git clone --filter=blob:none --no-checkout --depth 1 --sparse "$REPO_URL" "$TMP_DIR" > /dev/null 2>&1
cd "$TMP_DIR"
git sparse-checkout set "$TEMPLATE_PATH" > /dev/null 2>&1
git checkout main > /dev/null 2>&1
cd - > /dev/null

# 3. Apply Configuration
echo "📂 Applying configuration..."

if [ "$is_migration" = true ]; then
    if [ "$DRY_RUN" = true ]; then
        echo "📋 [Dry-Run] Migration Report:"
        echo "  - Would backup legacy files to .gemini.backup_<timestamp> and .agents.backup_<timestamp>"
        echo "  - Would inject the following new Template Agents into root .agents/:"
        ls -1 "$TMP_DIR/$TEMPLATE_PATH/.agents" | sed 's/^/      /'
        echo "  - Would overwrite root GEMINI.md with strictly JIT router rules"
        
        # Dry-run the jq merge preview
        if [ -f ".gemini/settings.json" ] && command -v jq &> /dev/null; then
            echo "  - Would merge settings.json:"
            echo ""
            jq -s '.[0] * .[1]' .gemini/settings.json "$TMP_DIR/$TEMPLATE_PATH/.gemini/settings.json"
            echo ""
        else
            echo "  - No local settings.json found or jq missing. Would implement template defaults."
        fi
        
        echo "🔍 Dry-run complete. Run without --dry-run to apply these changes."
        rm -rf "$TMP_DIR"
        exit 0
    fi

    # Migration Merge Logic A: Copy template agents directly in to root .agents/ (preserving existing legacy agents implicitly)
    mkdir -p .agents
    cp -R "$TMP_DIR/$TEMPLATE_PATH/.agents/"* .agents/ 2>/dev/null || true
    
    # Migration Merge Logic B: Deep merge settings.json (Install hooks without deleting custom MCPs)
    if [ -f ".gemini/settings.json" ] && command -v jq &> /dev/null; then
        echo "🧩 Merging settings.json via jq..."
        jq -s '.[0] * .[1]' .gemini/settings.json "$TMP_DIR/$TEMPLATE_PATH/.gemini/settings.json" > .gemini/settings_merged.json
        mv .gemini/settings_merged.json .gemini/settings.json
    else
        echo "⚠️  jq not found or settings missing. Overwriting settings.json with defaults. (Check .gemini.backup_${TIMESTAMP}/settings.json for your old MCPs)"
        cp -R "$TMP_DIR/$TEMPLATE_PATH/.gemini/settings.json" .gemini/
    fi

    # Migration Merge C: Overwrite root router and hooks
    cp -R "$TMP_DIR/$TEMPLATE_PATH/.gemini/hooks" .gemini/
    cp -R "$TMP_DIR/$TEMPLATE_PATH/.gemini/policies" .gemini/
    cp -R "$TMP_DIR/$TEMPLATE_PATH/.gemini/rules" .gemini/
    cp -R "$TMP_DIR/$TEMPLATE_PATH/.gemini/commands" .gemini/
    cp -R "$TMP_DIR/$TEMPLATE_PATH/.gemini/skills" .gemini/
    cp "$TMP_DIR/$TEMPLATE_PATH/.gemini/preferences.json" .gemini/
    cp "$TMP_DIR/$TEMPLATE_PATH/.gemini/GEMINI.md" .gemini/
else
    if [ "$DRY_RUN" = true ]; then
        echo "📋 [Dry-Run] Clean Install Report:"
        echo "  - Would install Gold Standard configuration to .gemini/ and .agents/"
        echo "🔍 Dry-run complete. Run without --dry-run to apply these changes."
        rm -rf "$TMP_DIR"
        exit 0
    fi

    # Clean Install
    cp -R "$TMP_DIR/$TEMPLATE_PATH/.gemini" .
    cp -R "$TMP_DIR/$TEMPLATE_PATH/.agents" .
    cp "$TMP_DIR/$TEMPLATE_PATH/external-catalog.json" .
    cp "$TMP_DIR/$TEMPLATE_PATH/.gemini/GEMINI.md" .gemini/
fi

cp -R "$TMP_DIR/$TEMPLATE_PATH/docs" .
cp "$TMP_DIR/$TEMPLATE_PATH/external-catalog.json" .
cp "$TMP_DIR/$TEMPLATE_PATH/.geminiignore" .
if [ -f "$TMP_DIR/$TEMPLATE_PATH/README.md" ]; then
    cp "$TMP_DIR/$TEMPLATE_PATH/README.md" ./GEMINI_README.md
fi
cp "$TMP_DIR/$TEMPLATE_PATH/.gemini/.env.example" .gemini/.env.example 2>/dev/null || true

# 4. Preference-Driven Tool Configuration
if [ -f ".gemini/preferences.json" ] && command -v jq &> /dev/null; then
    echo "⚙️  Configuring tools based on preferences..."
    PREFS=".gemini/preferences.json"
    SETTINGS=".gemini/settings.json"
    
    # Map preferences to MCP servers
    MEM_PREF=$(jq -r '.memory_preference // empty' "$PREFS")
    BROW_PREF=$(jq -r '.browser_preference // empty' "$PREFS")
    DEP_PREF=$(jq -r '.deploy_preference // empty' "$PREFS")
    PKM_PREF=$(jq -r '.pkm_preference // empty' "$PREFS")
    
    [ "$MEM_PREF" == "sqlite-local" ] && jq '.mcpServers.memory = {"command": "npx", "args": ["-y", "@pepk/mcp-memory-sqlite"]}' "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
    [ "$BROW_PREF" == "standalone-browser" ] && jq '.mcpServers.puppeteer = {"command": "npx", "args": ["puppeteer"]}' "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
    [ "$DEP_PREF" == "vercel" ] && jq '.mcpServers.vercel = {"command": "npx", "args": ["vercel-mcp"]}' "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
    [ "$PKM_PREF" == "obsidian" ] && jq '.mcpServers.obsidian = {"command": "npx", "args": ["obsidian-mcp"]}' "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
fi

# 5. Codebase Detection and Dependency Setup
if [ -f ".gemini/commands/detect-project.sh" ]; then
    chmod +x .gemini/commands/detect-project.sh
    sh .gemini/commands/detect-project.sh
fi

echo "📦 Setting up dependencies..."
if [ -f ".gemini/commands/setup-deps.sh" ]; then
    chmod +x .gemini/commands/setup-deps.sh
    sh .gemini/commands/setup-deps.sh
fi

# 5. Memory Initialization
echo "🧠 Initializing memory database..."
if [ -f ".gemini/hooks/sync-memory.sh" ]; then
    # Create an empty sqlite file if it doesn't exist
    if [ ! -f ".gemini/memory.sqlite" ]; then
        sqlite3 .gemini/memory.sqlite "VACUUM;"
        echo "  ✅ Created .gemini/memory.sqlite"
    fi
    # Run sync to establish WAL state
    sh .gemini/hooks/sync-memory.sh
    echo "  ✅ Memory graph initialized."
fi

# 6. Clean up
rm -rf "$TMP_DIR"
echo "🔧 Setting hook permissions..."
chmod +x .gemini/hooks/*.sh
[ -d ".gemini/commands" ] && chmod +x .gemini/commands/*.sh

echo ""
echo "✅ Initialization & Migration Complete!"

if [ "$is_migration" = true ]; then
    echo "🚨 MIGRATION CONTEXT REQUIRED: Please review your legacy configuration backed up at .gemini.backup_${TIMESTAMP}/"
    echo "   Add any custom legacy instructions into the appropriate overlay agent, or define a new one."
    echo "   The JIT Router (GEMINI.md) is now strictly locked to the Gold Standard templates. Automatic installation complete."
    echo ""
    echo "🔑 Don't forget to configure your API keys! Copy .gemini/.env.example to .env and edit."
    echo "🚀 To trigger the new autonomous workflow, run:"
    echo "   gemini chat 'I want to build a new feature. Please trigger the Architect.'"
else
    echo "🔑 Don't forget to configure your API keys! Copy .gemini/.env.example to .env and edit."
    echo "🚀 To trigger the new autonomous workflow, run:"
    echo "   gemini chat 'I want to build a new feature. Please trigger the Architect.'"
fi
