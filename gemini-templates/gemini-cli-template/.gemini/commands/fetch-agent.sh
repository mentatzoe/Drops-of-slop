#!/usr/bin/env bash

# fetch-agent.sh
# Robust Agent Fetcher: Downloads, standardizes, and secures new agent capabilities.

URL="$1"
AGENT_NAME="$2"
TARGET_DIR=".agents"
GUARDRAILS="@.gemini/policies/guardrails.toml"

if [ -z "$URL" ] || [ -z "$AGENT_NAME" ]; then
    echo "Usage: sh .gemini/commands/fetch-agent.sh <URL> <AGENT_NAME>"
    exit 1
fi

echo "📂 Fetching agent '$AGENT_NAME' from $URL..."

# Create temp file
TEMP_FILE=$(mktemp)

# Download with curl
if ! curl -fsSL "$URL" > "$TEMP_FILE"; then
    echo "❌ [ERROR] Failed to download agent from $URL" >&2
    rm -f "$TEMP_FILE"
    exit 1
fi

# Validate it's not a 404/HTML error page
if grep -q "<!DOCTYPE html>" "$TEMP_FILE" || [ ! -s "$TEMP_FILE" ]; then
    echo "❌ [ERROR] Invalid response from server (possible 404 or empty file)." >&2
    rm -f "$TEMP_FILE"
    exit 1
fi

# Core Processing: Inject Guardrails and Ensure Triggers
# We use awk to handle the frontmatter and body separation.

awk -v guardrails="@.gemini/policies/guardrails.toml" '
BEGIN { 
    fm_count = 0; 
    has_triggers = 0;
    has_description = 0;
}
/^---/ { 
    fm_count++; 
    if (fm_count == 2) {
        if (!has_triggers) {
            if (has_description) {
                # Add triggers after description if it exists
                # This is a bit tricky in standard awk without regex capture groups
                # We will just append it before the closing --- if missing
            }
            print "triggers: []";
        }
    }
    print $0;
    next;
}
fm_count == 1 {
    if ($0 ~ /^triggers:/) has_triggers = 1;
    if ($0 ~ /^description:/) has_description = 1;
    print $0;
    next;
}
fm_count == 2 {
    print guardrails;
    print "";
    fm_count = 3;
}
{ print $0 }
' "$TEMP_FILE" > "$TARGET_DIR/$AGENT_NAME.md"

# Cleanup
rm -f "$TEMP_FILE"

# Log event
if [ -f ".gemini/telemetry.json" ]; then
    TIMESTAMP=$(date +"%Y-%m-%dT%H:%M:%SZ")
    echo "{\"timestamp\": \"$TIMESTAMP\", \"event\": \"agent_fetched\", \"name\": \"$AGENT_NAME\", \"url\": \"$URL\"}" >> .gemini/telemetry.json
fi

echo "✅ [SUCCESS] Agent '$AGENT_NAME' installed at $TARGET_DIR/$AGENT_NAME.md"
