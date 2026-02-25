#!/usr/bin/env bash

# index-agents.sh
# Dynamic Agent Discovery Indexer: Generates a capability map from agent frontmatter.

AGENT_DIR=".agents"
OUTPUT_FILE="docs/agent-map.md"

echo "🔍 Indexing agents from $AGENT_DIR..."

cat << EOF > "$OUTPUT_FILE"
# Agent Capability Map
This document is automatically generated. Do not edit manually. It serves as the primary discovery source for the Gemini Router.

| Agent | Entry Point | Intent Triggers | Description |
| :--- | :--- | :--- | :--- |
EOF

for agent_file in "$AGENT_DIR"/*.md; do
    [ -e "$agent_file" ] || continue
    
    filename=$(basename "$agent_file")
    
    # Extract metadata using awk/sed to avoid heavy dependencies
    name=$(grep "^name:" "$agent_file" | sed 's/name: //; s/"//g')
    description=$(grep "^description:" "$agent_file" | sed 's/description: //; s/"//g')
    triggers=$(grep "^triggers:" "$agent_file" | sed 's/triggers: //; s/\[//; s/\]//; s/"//g')
    
    # Fallback to filename if name is missing
    if [ -z "$name" ]; then name="$filename"; fi
    
    echo "| **$name** | [\`$filename\`](file:///../.agents/$filename) | $triggers | $description |" >> "$OUTPUT_FILE"
done

echo "✅ Generated $OUTPUT_FILE"
