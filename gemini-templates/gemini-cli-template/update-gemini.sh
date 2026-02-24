#!/usr/bin/env bash

# Gemini CLI Template Update Tool
# Safely pulls new template updates (Agents, MCPs, Catalog) without destroying local context.

set -e

VERSION="main"
DRY_RUN=${DRY_RUN:-false}

for arg in "$@"; do
    case "$arg" in
        --version=*|-v=*) VERSION="${arg#*=}" ;;
        --dry-run|-d) DRY_RUN=true ;;
    esac
done

echo "🔄 Updating Gemini CLI Workspace to version: $VERSION..."
if [ "$DRY_RUN" = true ]; then
    echo "🔍 DRY-RUN MODE ACTIVATED: No files will be modified."
fi

REPO_URL="https://github.com/mentatzoe/Drops-of-slop.git"
TEMPLATE_PATH="gemini-templates/gemini-cli-template"

echo "📥 Fetching upstream template ($VERSION)..."
TMP_DIR=$(mktemp -d)

git clone --filter=blob:none --no-checkout --depth 1 --sparse -b "$VERSION" "$REPO_URL" "$TMP_DIR" > /dev/null 2>&1
cd "$TMP_DIR"
git sparse-checkout set "$TEMPLATE_PATH" > /dev/null 2>&1
git checkout "$VERSION" > /dev/null 2>&1
cd - > /dev/null

echo "📂 Syncing new capabilities non-destructively..."

if [ "$DRY_RUN" = true ]; then
    echo "  - Would update external-catalog.json"
    echo "  - Would copy new .agents/ without overwriting user modifications"
    echo "  - Would deep merge .gemini/settings.json using jq"
    echo "  - Would overwrite core hooks, rules, and policies"
    rm -rf "$TMP_DIR"
    exit 0
fi

# 1. Update Catalog
if [ -f "$TMP_DIR/$TEMPLATE_PATH/external-catalog.json" ]; then
    cp "$TMP_DIR/$TEMPLATE_PATH/external-catalog.json" ./external-catalog.json
    echo "✅ Updated external-catalog.json"
fi

# 2. Add New Agents Non-Destructively
mkdir -p .agents
for agent in "$TMP_DIR/$TEMPLATE_PATH/.agents/"*.md; do
    [ -e "$agent" ] || continue
    filename=$(basename "$agent")
    if [ ! -f ".agents/$filename" ]; then
        cp "$agent" ".agents/$filename"
        echo "✅ Installed new default agent: $filename"
    fi
done

# 3. Deep Merge settings.json
if [ -f ".gemini/settings.json" ] && command -v jq &> /dev/null; then
    jq -s '.[0] * .[1]' .gemini/settings.json "$TMP_DIR/$TEMPLATE_PATH/.gemini/settings.json" > .gemini/settings_merged.json
    mv .gemini/settings_merged.json .gemini/settings.json
    echo "✅ Merged settings.json (preserving your custom MCPs)"
fi

# 4. Update core infrastructure (hooks/policies/rules) - always safe to overwrite
cp -R "$TMP_DIR/$TEMPLATE_PATH/.gemini/hooks/"* .gemini/hooks/ 2>/dev/null || true
cp -R "$TMP_DIR/$TEMPLATE_PATH/.gemini/policies/"* .gemini/policies/ 2>/dev/null || true
chmod +x .gemini/hooks/*.sh 2>/dev/null || true
echo "✅ Enforced core security hooks and policies"

rm -rf "$TMP_DIR"
echo ""
echo "🎉 Update complete! Your local context (GEMINI.md) and custom agents have been preserved."
