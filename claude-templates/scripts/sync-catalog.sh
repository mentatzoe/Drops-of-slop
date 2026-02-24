#!/usr/bin/env bash
# sync-catalog.sh — Fetches component listings from the external claude-code-templates
# GitHub repo and builds external-catalog.json for offline browsing and install.
#
# Usage:
#   ./scripts/sync-catalog.sh
#
# Environment:
#   GITHUB_TOKEN — Optional. Authenticated requests get 5000 req/hr vs 60 unauthenticated.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
CATALOG_FILE="$REPO_DIR/external-catalog.json"

GITHUB_REPO="davila7/claude-code-templates"
GITHUB_API="https://api.github.com"
COMPONENTS_PATH="cli-tool/components"
COMPONENT_TYPES=("agents" "commands" "skills" "mcps" "hooks" "settings")

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

error() { echo -e "${RED}ERROR:${NC} $1" >&2; exit 1; }
warn() { echo -e "${YELLOW}WARN:${NC} $1" >&2; }
info() { echo -e "${GREEN}>>>${NC} $1"; }

# Build auth header if GITHUB_TOKEN is set
AUTH_HEADER=()
if [ -n "${GITHUB_TOKEN:-}" ]; then
    AUTH_HEADER=(-H "Authorization: token $GITHUB_TOKEN")
    info "Using authenticated GitHub API (5000 req/hr limit)"
else
    warn "No GITHUB_TOKEN set. Using unauthenticated API (60 req/hr limit)."
    warn "Set GITHUB_TOKEN for higher rate limits."
fi

# Fetch with exponential backoff on rate limiting
github_api_get() {
    local url="$1"
    local max_retries=3
    local retry=0
    local wait=2

    while [ "$retry" -lt "$max_retries" ]; do
        local response
        local http_code
        http_code=$(curl -s -o /tmp/gh_api_response.json -w "%{http_code}" \
            "${AUTH_HEADER[@]}" \
            -H "Accept: application/vnd.github.v3+json" \
            "$url" 2>/dev/null) || true

        if [ "$http_code" = "200" ]; then
            cat /tmp/gh_api_response.json
            return 0
        elif [ "$http_code" = "403" ] || [ "$http_code" = "429" ]; then
            retry=$((retry + 1))
            if [ "$retry" -lt "$max_retries" ]; then
                warn "Rate limited (HTTP $http_code). Retrying in ${wait}s... (attempt $((retry+1))/$max_retries)"
                sleep "$wait"
                wait=$((wait * 2))
            else
                warn "Rate limited after $max_retries retries. Skipping: $url"
                echo "[]"
                return 1
            fi
        elif [ "$http_code" = "404" ]; then
            echo "[]"
            return 0
        else
            warn "HTTP $http_code for $url"
            echo "[]"
            return 1
        fi
    done
}

# List directories within a GitHub path
list_dirs() {
    local path="$1"
    github_api_get "$GITHUB_API/repos/$GITHUB_REPO/contents/$path" | \
        python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    if isinstance(data, list):
        for item in data:
            if item.get('type') == 'dir':
                print(item['name'])
except (json.JSONDecodeError, KeyError):
    pass
" 2>/dev/null
}

# List files within a GitHub path
list_files() {
    local path="$1"
    github_api_get "$GITHUB_API/repos/$GITHUB_REPO/contents/$path" | \
        python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    if isinstance(data, list):
        for item in data:
            if item.get('type') == 'file':
                print(item['name'])
except (json.JSONDecodeError, KeyError):
    pass
" 2>/dev/null
}

info "Syncing external catalog from github.com/$GITHUB_REPO..."
info "This may take a moment (enumerating all component categories)..."

# Build catalog JSON using Python
python3 - "$CATALOG_FILE" "$GITHUB_API" "$GITHUB_REPO" "$COMPONENTS_PATH" << 'PYEOF'
import json
import subprocess
import sys
import os
from datetime import datetime, timezone

catalog_file = sys.argv[1]
github_api = sys.argv[2]
github_repo = sys.argv[3]
components_path = sys.argv[4]

component_types = ["agents", "commands", "skills", "mcps", "hooks", "settings"]

# Build curl auth args
auth_args = []
github_token = os.environ.get("GITHUB_TOKEN", "")
if github_token:
    auth_args = ["-H", f"Authorization: token {github_token}"]

def api_get(path):
    """Fetch GitHub API endpoint with retries."""
    url = f"{github_api}/repos/{github_repo}/contents/{path}"
    max_retries = 3
    wait = 2
    for attempt in range(max_retries):
        try:
            result = subprocess.run(
                ["curl", "-s", "-w", "\n%{http_code}"] + auth_args +
                ["-H", "Accept: application/vnd.github.v3+json", url],
                capture_output=True, text=True, timeout=30
            )
            lines = result.stdout.strip().rsplit("\n", 1)
            if len(lines) == 2:
                body, code = lines
                if code == "200":
                    return json.loads(body)
                elif code in ("403", "429"):
                    if attempt < max_retries - 1:
                        import time
                        print(f"  Rate limited, retrying in {wait}s...", file=sys.stderr)
                        time.sleep(wait)
                        wait *= 2
                        continue
                    return []
                elif code == "404":
                    return []
            return []
        except Exception as e:
            print(f"  Error fetching {path}: {e}", file=sys.stderr)
            return []
    return []

catalog = {
    "version": "1.0.0",
    "fetched_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "source": f"github.com/{github_repo}",
    "components": {}
}

for comp_type in component_types:
    print(f"  Scanning {comp_type}...", file=sys.stderr)
    catalog["components"][comp_type] = []

    type_path = f"{components_path}/{comp_type}"
    categories = api_get(type_path)

    if not isinstance(categories, list):
        continue

    for cat_entry in categories:
        if cat_entry.get("type") != "dir":
            continue
        cat_name = cat_entry["name"]
        # Skip hidden directories
        if cat_name.startswith("."):
            continue

        cat_path = f"{type_path}/{cat_name}"
        items = api_get(cat_path)

        if not isinstance(items, list):
            continue

        for item in items:
            item_name = item["name"]
            item_type = item.get("type", "file")

            # Skip non-component files (READMEs, attribution notices, etc.)
            if item_name.startswith(".") or item_name == "ANTHROPIC_ATTRIBUTION.md":
                continue

            # Determine component name (strip extension for files)
            if item_type == "file":
                if item_name.endswith(".md"):
                    name = item_name[:-3]
                elif item_name.endswith(".json"):
                    name = item_name[:-5]
                else:
                    name = item_name
            else:
                name = item_name

            entry = {
                "name": name,
                "category": cat_name,
                "path": f"{cat_name}/{name}",
                "github_path": item["path"]
            }
            catalog["components"][comp_type].append(entry)

    count = len(catalog["components"][comp_type])
    print(f"  Found {count} {comp_type}", file=sys.stderr)

# Write catalog
with open(catalog_file, "w") as f:
    json.dump(catalog, f, indent=2)
    f.write("\n")

total = sum(len(v) for v in catalog["components"].values())
print(f"\nCatalog written to {catalog_file} ({total} components total)", file=sys.stderr)
PYEOF

info "Catalog sync complete!"
info "View with: cat $CATALOG_FILE | python3 -m json.tool | head -50"
