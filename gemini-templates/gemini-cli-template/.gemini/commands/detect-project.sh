#!/usr/bin/env bash

# detect-project.sh
# Heuristically identifies codebase context to recommend MCP servers.

CATALOG_PATH="${1:-external-catalog.json}"
RECOMMENDATIONS=()

echo "🔍 Scanning codebase for context..."

# 1. Node.js / Frontend / Web
if [ -f "package.json" ] || [ -d "node_modules" ]; then
    echo "  ✅ Detected: Node.js / Web Development"
    RECOMMENDATIONS+=("web-development" "frontend" "backend" "api-graphql")
fi

# 2. Python
if [ -f "requirements.txt" ] || [ -f "setup.py" ] || [ -d "venv" ]; then
    echo "  ✅ Detected: Python Development"
    RECOMMENDATIONS+=("data-science" "mlops" "data-ai")
fi

# 3. Java / Kotlin / Android
if [ -f "pom.xml" ] || [ -f "build.gradle" ]; then
    echo "  ✅ Detected: Java / Kotlin / Android Development"
    RECOMMENDATIONS+=("android" "gradle")
fi

# 4. Git / Version Control
if [ -d ".git" ]; then
    echo "  ✅ Detected: Git Repository"
    RECOMMENDATIONS+=("version-control" "github" "devops")
fi

# 5. Cloud / Deployment
if [ -f "vercel.json" ] || [ -f "netlify.toml" ] || [ -d ".github/workflows" ]; then
    echo "  ✅ Detected: Cloud / CI/CD Configuration"
    RECOMMENDATIONS+=("deployment" "vercel" "ci-cd")
fi

# 6. Database / SQL
if grep -rinq "SELECT\|FROM\|INSERT\|CREATE TABLE" . --exclude-dir=".gemini" --exclude-dir=".git" --max-count=1; then
    echo "  ✅ Detected: SQL / Database presence"
    RECOMMENDATIONS+=("database" "postgresql" "sql")
fi

# De-duplicate recommendations
UNIQUE_RECS=$(printf "%s\n" "${RECOMMENDATIONS[@]}" | sort -u | tr '\n' ' ')

echo ""
echo "💡 Suggested MCP Categories based on your code:"
echo "$UNIQUE_RECS"
echo ""
echo "Run '.gemini/commands/mcp-wizard.sh' to explore tools in these categories."
