#!/usr/bin/env bash

# Gemini CLI Template Initializer
# Downloads and installs the Gemini CLI Gold Standard Template into the current directory.

set -e

REPO_URL="https://github.com/mentatzoe/Drops-of-slop.git"
TEMPLATE_PATH="gemini-templates/gemini-cli-template"

echo "💎 Initializing Gemini CLI Workspace..."

# 1. Check if .gemini already exists
if [ -d ".gemini" ]; then
    echo "⚠️  A .gemini directory already exists in this project."
    echo "Please back it up or remove it before initializing the template."
    exit 1
fi

# 2. Clone the template using sparse-checkout to grab ONLY the template directory
echo "📥 Fetching template from $REPO_URL..."
TMP_DIR=$(mktemp -d)

git clone --filter=blob:none --no-checkout --depth 1 --sparse "$REPO_URL" "$TMP_DIR" > /dev/null 2>&1
cd "$TMP_DIR"
git sparse-checkout set "$TEMPLATE_PATH" > /dev/null 2>&1
git checkout main > /dev/null 2>&1
cd - > /dev/null

# 3. Copy the template contents to the current directory
echo "📂 Applying configuration..."
cp -R "$TMP_DIR/$TEMPLATE_PATH/.gemini" .
cp -R "$TMP_DIR/$TEMPLATE_PATH/docs" .
cp "$TMP_DIR/$TEMPLATE_PATH/.geminiignore" .
cp "$TMP_DIR/$TEMPLATE_PATH/README.md" ./GEMINI_README.md

# 4. Clean up temporary directory
rm -rf "$TMP_DIR"

# 5. Fix executable permissions for hooks
echo "🔧 Setting hook permissions..."
chmod +x .gemini/hooks/*.sh

echo ""
echo "✅ Initialization Complete!"
echo "   - .gemini/ configured."
echo "   - docs/ established."
echo "   - .geminiignore applied."
echo "   - Template documentation saved as GEMINI_README.md."
echo ""
echo "🚀 To trigger the autonomous workflow, run:"
echo "   gemini chat 'I want to build a new feature. Please trigger the Architect.'"
