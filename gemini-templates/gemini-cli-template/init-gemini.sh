#!/usr/bin/env bash

# Gemini CLI Template Initializer
# Downloads and installs the Gemini CLI Gold Standard Template into the current directory.
# Features a safe, LLM-driven migration path for existing setups.

set -e

REPO_URL="https://github.com/mentatzoe/Drops-of-slop.git"
TEMPLATE_PATH="gemini-templates/gemini-cli-template"

echo "💎 Initializing Gemini CLI Workspace..."

is_migration=false

# 1. Detect existing setup and ask for Migration
if [ -d ".gemini" ] || [ -f "GEMINI.md" ]; then
    echo "⚠️  Existing Gemini configuration detected."
    read -p "Do you want to safely migrate your existing setup to the Gold Standard architecture? [y/N] " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        is_migration=true
        TIMESTAMP=$(date +%s)
        echo "📦 Creating backups..."
        [ -d ".gemini" ] && cp -R .gemini ".gemini.backup_${TIMESTAMP}"
        [ -f "GEMINI.md" ] && cp GEMINI.md "GEMINI.backup_${TIMESTAMP}.md"
    else
        echo "Aborting initialization to protect existing files."
        exit 1
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
    # Migration Merge Logic A: Copy template agents directly in (preserving existing legacy agents implicitly)
    cp -R "$TMP_DIR/$TEMPLATE_PATH/.gemini/agents/"* .gemini/agents/ 2>/dev/null || true
    
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
    cp "$TMP_DIR/$TEMPLATE_PATH/.gemini/GEMINI.md" .gemini/
else
    # Clean Install
    cp -R "$TMP_DIR/$TEMPLATE_PATH/.gemini" .
    cp "$TMP_DIR/$TEMPLATE_PATH/.gemini/GEMINI.md" .gemini/
fi

cp -R "$TMP_DIR/$TEMPLATE_PATH/docs" .
cp "$TMP_DIR/$TEMPLATE_PATH/.geminiignore" .
if [ -f "$TMP_DIR/$TEMPLATE_PATH/README.md" ]; then
    cp "$TMP_DIR/$TEMPLATE_PATH/README.md" ./GEMINI_README.md
fi

# 4. Clean up
rm -rf "$TMP_DIR"
echo "🔧 Setting hook permissions..."
chmod +x .gemini/hooks/*.sh

echo ""
echo "✅ Initialization & Migration Complete!"

if [ "$is_migration" = true ]; then
    echo "🚨 MIGRATION CONTEXT REQUIRED: Please review your legacy configuration backed up at .gemini.backup_${TIMESTAMP}/"
    echo "   Add any custom legacy instructions into the appropriate overlay agent, or define a new one."
    echo "   The JIT Router (GEMINI.md) is now strictly locked to the Gold Standard templates. Automatic installation complete."
    echo ""
    echo "🚀 To trigger the new autonomous workflow, run:"
    echo "   gemini chat 'I want to build a new feature. Please trigger the Architect.'"
else
    echo "🚀 To trigger the new autonomous workflow, run:"
    echo "   gemini chat 'I want to build a new feature. Please trigger the Architect.'"
fi
