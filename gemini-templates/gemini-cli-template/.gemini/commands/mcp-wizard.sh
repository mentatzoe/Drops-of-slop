#!/usr/bin/env bash

# mcp-wizard.sh
# Interactive CLI to browse and install MCP servers with Preference-Aware Checklisting.

CATALOG="external-catalog.json"
SETTINGS=".gemini/settings.json"
ENV_EX=".gemini/.env.example"
PREFS=".gemini/preferences.json"

if [ ! -f "$CATALOG" ]; then
    echo "❌ Error: $CATALOG not found."
    exit 1
fi

echo "🧙 Welcome to the Gemini MCP Wizard!"
echo "-----------------------------------"

# Load Preferences
if [ -f "$PREFS" ]; then
    PKM_PREF=$(jq -r '.pkm_preference' "$PREFS")
    MEM_PREF=$(jq -r '.memory_preference' "$PREFS")
    echo "⚙️  Detected Preferences: PKM=$PKM_PREF, Memory=$MEM_PREF"
fi

# 1. Run detection for context
if [ -f ".gemini/commands/detect-project.sh" ]; then
    sh .gemini/commands/detect-project.sh
fi

echo "Available Categories:"
CATEGORIES=$(jq -r '.components."mcp-servers" | map(.type) | unique | .[]' "$CATALOG")
select CATEGORY in $CATEGORIES "Exit"; do
    if [ "$CATEGORY" == "Exit" ]; then break; fi
    if [ -n "$CATEGORY" ]; then
        echo "--- $CATEGORY Servers ---"
        SERVERS=$(jq -r --arg type "$CATEGORY" '.components."mcp-servers"[] | select(.type == $type) | .name' "$CATALOG")
        
        select SERVER in $SERVERS "Back"; do
            if [ "$SERVER" == "Back" ]; then break; fi
            if [ -n "$SERVER" ]; then
                echo "📦 Installing $SERVER..."
                
                # Extract server config
                SERVER_DATA=$(jq -r --arg name "$SERVER" '.components."mcp-servers"[] | select(.name == $name)' "$CATALOG")
                COMMAND=$(echo "$SERVER_DATA" | jq -r '.command // "npx"')
                ARGS=$(echo "$SERVER_DATA" | jq -r '.args // [] | join(",")')
                PKG=$(echo "$SERVER_DATA" | jq -r '.package_name // empty')
                
                # Check for preference match (Non-Strict)
                IS_PKM=$(echo "$CATEGORY" | grep -i "pkm\|wiki\|documentation" || true)
                if [ -n "$IS_PKM" ] && [ "$SERVER" != "$PKM_PREF" ]; then
                    echo "⚠️  Note: Your global preference is set to '$PKM_PREF'."
                    read -p "Install $SERVER anyway? [y/N] " confirm
                    [[ ! "$confirm" =~ ^[Yy]$ ]] && continue
                fi

                # Construct JSON fragment
                if [ -n "$PKG" ]; then
                   FRAGMENT="{\"$SERVER\": {\"command\": \"$COMMAND\", \"args\": [\"-y\", \"$PKG\"]}}"
                else
                   FRAGMENT="{\"$SERVER\": {\"command\": \"$COMMAND\", \"args\": [\"$SERVER\"]}}"
                fi

                # Merge into settings.json
                jq -s ".[0] * {\"mcpServers\": $FRAGMENT}" "$SETTINGS" "$SETTINGS" > "${SETTINGS}.tmp" && mv "${SETTINGS}.tmp" "$SETTINGS"
                echo "✅ Added $SERVER to $SETTINGS"

                # Inject placeholder into .env.example
                VARS=$(echo "$SERVER_DATA" | jq -r '.env_vars // [] | .[]')
                for var in $VARS; do
                    if ! grep -q "$var" "$ENV_EX"; then
                        echo "" >> "$ENV_EX"
                        echo "# PREREQUISITE: $SERVER integration" >> "$ENV_EX"
                        echo "$var=\"your_${var}_here\"" >> "$ENV_EX"
                    fi
                done
                
                echo "🎉 Done! Restart your Gemini session to use the new tools."
                break 2
            fi
        done
    fi
done
