#!/usr/bin/env bash
# fetch-external.sh — Fetch and install external components from claude-code-templates (aitmpl.com).
#
# Usage:
#   ./scripts/fetch-external.sh catalog [--type agent|command|skill|mcp|hook|setting] [--search <term>]
#   ./scripts/fetch-external.sh install <target-path> --agent <cat/name> [--command <cat/name>] ...
#   ./scripts/fetch-external.sh install <target-path> --recommended
#   ./scripts/fetch-external.sh remove <target-path> --agent <name> [--command <name>] ...
#   ./scripts/fetch-external.sh sync-catalog
#
# Components are cached locally in cache/ for offline reuse.
# External files use the ext-- prefix to prevent collisions with local overlays.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
CATALOG_FILE="$REPO_DIR/external-catalog.json"
CACHE_DIR="$REPO_DIR/cache"
SCRIPTS_DIR="$REPO_DIR/scripts"

GITHUB_REPO="davila7/claude-code-templates"
RAW_BASE="https://raw.githubusercontent.com/$GITHUB_REPO/main"
GITHUB_API="https://api.github.com"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

error() { echo -e "${RED}ERROR:${NC} $1" >&2; exit 1; }
warn() { echo -e "${YELLOW}WARN:${NC} $1" >&2; }
info() { echo -e "${GREEN}>>>${NC} $1"; }

usage() {
    cat <<EOF
Usage:
  $(basename "$0") catalog [--type TYPE] [--search TERM]
      Browse the external component catalog.
      TYPE: agent, command, skill, mcp, hook, setting
      TERM: search string to filter component names/categories

  $(basename "$0") install <target-path> OPTIONS
      Install external components into a target project.
      Options:
        --agent <category/name>      Install an agent
        --command <category/name>    Install a command
        --skill <category/name>      Install a skill
        --mcp <category/name>        Install an MCP server
        --hook <category/name>       Install a hook
        --setting <category/name>    Install a setting
        --recommended                Install overlay-recommended externals

  $(basename "$0") remove <target-path> OPTIONS
      Remove installed external components.
      Options:
        --agent <name>     Remove an agent
        --command <name>   Remove a command
        --skill <name>     Remove a skill
        --mcp <name>       Remove an MCP server
        --hook <name>      Remove a hook
        --setting <name>   Remove a setting

  $(basename "$0") sync-catalog
      Refresh the cached component catalog from GitHub.
EOF
    exit 1
}

[ $# -lt 1 ] && usage

# --- Ensure catalog exists ---

ensure_catalog() {
    if [ ! -f "$CATALOG_FILE" ]; then
        warn "No catalog found. Running sync first..."
        "$SCRIPTS_DIR/sync-catalog.sh"
    fi
}

# --- Auth header for GitHub API ---

AUTH_ARGS=()
if [ -n "${GITHUB_TOKEN:-}" ]; then
    AUTH_ARGS=(-H "Authorization: token $GITHUB_TOKEN")
fi

# --- Download a file from GitHub raw content ---

download_file() {
    local github_path="$1"
    local dest="$2"
    local cache_path="$CACHE_DIR/$github_path"

    # Try cache first
    if [ -f "$cache_path" ]; then
        mkdir -p "$(dirname "$dest")"
        cp "$cache_path" "$dest"
        info "  Installed from cache: $(basename "$dest")"
        return 0
    fi

    # Download from GitHub
    local url="$RAW_BASE/$github_path"
    mkdir -p "$(dirname "$dest")"
    mkdir -p "$(dirname "$cache_path")"

    local http_code
    http_code=$(curl -s -o "$dest" -w "%{http_code}" "${AUTH_ARGS[@]}" "$url" 2>/dev/null) || true

    if [ "$http_code" = "200" ]; then
        # Cache the file
        cp "$dest" "$cache_path"
        info "  Downloaded: $(basename "$dest")"
        return 0
    else
        rm -f "$dest"
        warn "  Failed to download $github_path (HTTP $http_code)"
        return 1
    fi
}

# --- Download a skill directory (multiple files) ---

download_skill_dir() {
    local github_dir_path="$1"
    local dest_dir="$2"
    local cache_dir="$CACHE_DIR/$github_dir_path"

    # Try cache first
    if [ -d "$cache_dir" ] && [ -n "$(ls -A "$cache_dir" 2>/dev/null)" ]; then
        mkdir -p "$dest_dir"
        cp -r "$cache_dir"/* "$dest_dir/" 2>/dev/null || true
        info "  Installed skill from cache: $(basename "$dest_dir")"
        return 0
    fi

    # List directory contents via GitHub API
    local api_url="$GITHUB_API/repos/$GITHUB_REPO/contents/$github_dir_path"
    local listing
    listing=$(curl -s "${AUTH_ARGS[@]}" -H "Accept: application/vnd.github.v3+json" "$api_url" 2>/dev/null)

    mkdir -p "$dest_dir"
    mkdir -p "$cache_dir"

    echo "$listing" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    if isinstance(data, list):
        for item in data:
            if item.get('type') == 'file':
                print(item['name'] + '|' + item['path'])
            elif item.get('type') == 'dir':
                print('DIR|' + item['name'] + '|' + item['path'])
except:
    pass
" 2>/dev/null | while IFS='|' read -r name_or_flag rest_or_path extra_path; do
        if [ "$name_or_flag" = "DIR" ]; then
            # Recurse into subdirectory
            download_skill_dir "$extra_path" "$dest_dir/$rest_or_path"
        else
            # Download file
            local file_name="$name_or_flag"
            local file_path="$rest_or_path"
            local file_url="$RAW_BASE/$file_path"
            curl -s "${AUTH_ARGS[@]}" -o "$dest_dir/$file_name" "$file_url" 2>/dev/null
            cp "$dest_dir/$file_name" "$cache_dir/$file_name" 2>/dev/null || true
        fi
    done

    info "  Downloaded skill directory: $(basename "$dest_dir")"
    return 0
}

# --- Resolve component from catalog ---

resolve_component() {
    local comp_type="$1"  # agents, commands, etc.
    local comp_path="$2"  # category/name

    python3 -c "
import json, sys
with open('$CATALOG_FILE') as f:
    catalog = json.load(f)
components = catalog.get('components', {}).get('$comp_type', [])
for c in components:
    if c['path'] == '$comp_path':
        print(json.dumps(c))
        sys.exit(0)
print('')
" 2>/dev/null
}

# --- Read/write state file ---

read_state() {
    local target="$1"
    local state_file="$target/.claude/.activated-overlays.json"
    local template_version
    template_version=$(cat "$REPO_DIR/VERSION" 2>/dev/null || echo "unknown")
    # Migrate state file to current schema before reading
    python3 "$SCRIPTS_DIR/migrate-state.py" "$state_file" --template-version "$template_version" 2>/dev/null || true
    if [ -f "$state_file" ]; then
        cat "$state_file"
    else
        echo '{}'
    fi
}

write_state() {
    local target="$1"
    local state_json="$2"
    local state_file="$target/.claude/.activated-overlays.json"
    mkdir -p "$target/.claude"
    echo "$state_json" > "$state_file"
}

# --- Install a single component ---

install_component() {
    local target="$1"
    local comp_type="$2"    # agent, command, skill, mcp, hook, setting
    local comp_path="$3"    # category/name

    # Map singular to plural for catalog lookup
    local catalog_type="${comp_type}s"

    local comp_json
    comp_json=$(resolve_component "$catalog_type" "$comp_path")

    if [ -z "$comp_json" ]; then
        warn "Component not found in catalog: $catalog_type/$comp_path"
        warn "Try: $0 catalog --type $comp_type --search $(basename "$comp_path")"
        return 1
    fi

    local comp_name github_path
    comp_name=$(echo "$comp_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['name'])")
    github_path=$(echo "$comp_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['github_path'])")

    local state
    state=$(read_state "$target")

    case "$comp_type" in
        agent)
            local dest="$target/.claude/agents/ext--${comp_name}.md"
            mkdir -p "$target/.claude/agents"
            download_file "$github_path" "$dest" || return 1
            state=$(echo "$state" | python3 -c "
import json, sys
state = json.load(sys.stdin)
ec = state.setdefault('external_components', {})
agents = ec.setdefault('agents', [])
entry = {'name': '$comp_name', 'source': '$comp_path', 'installed_to': '.claude/agents/ext--${comp_name}.md'}
# Avoid duplicates
agents = [a for a in agents if a['name'] != '$comp_name']
agents.append(entry)
ec['agents'] = agents
print(json.dumps(state, indent=2))
")
            ;;
        command)
            local dest="$target/.claude/commands/ext--${comp_name}.md"
            mkdir -p "$target/.claude/commands"
            download_file "$github_path" "$dest" || return 1
            state=$(echo "$state" | python3 -c "
import json, sys
state = json.load(sys.stdin)
ec = state.setdefault('external_components', {})
commands = ec.setdefault('commands', [])
entry = {'name': '$comp_name', 'source': '$comp_path', 'installed_to': '.claude/commands/ext--${comp_name}.md'}
commands = [c for c in commands if c['name'] != '$comp_name']
commands.append(entry)
ec['commands'] = commands
print(json.dumps(state, indent=2))
")
            ;;
        skill)
            local dest_dir="$target/.claude/skills/ext--${comp_name}"
            mkdir -p "$target/.claude/skills"
            download_skill_dir "$github_path" "$dest_dir" || return 1
            state=$(echo "$state" | python3 -c "
import json, sys
state = json.load(sys.stdin)
ec = state.setdefault('external_components', {})
skills = ec.setdefault('skills', [])
entry = {'name': '$comp_name', 'source': '$comp_path', 'installed_to': '.claude/skills/ext--${comp_name}/'}
skills = [s for s in skills if s['name'] != '$comp_name']
skills.append(entry)
ec['skills'] = skills
print(json.dumps(state, indent=2))
")
            ;;
        mcp)
            # Download the MCP JSON, then merge into .mcp.json
            local cache_file="$CACHE_DIR/$github_path"
            local tmp_file="/tmp/ext-mcp-${comp_name}.json"
            download_file "$github_path" "$tmp_file" || return 1

            # Extract server names from the downloaded MCP config
            local server_names
            server_names=$(python3 -c "
import json
with open('$tmp_file') as f:
    data = json.load(f)
servers = data.get('mcpServers', {})
for name in servers:
    print(name)
" 2>/dev/null)

            # Merge: existing .mcp.json + new external MCP
            if [ -f "$target/.mcp.json" ]; then
                python3 "$SCRIPTS_DIR/merge-configs.py" --type mcp --output "$target/.mcp.json" \
                    "$target/.mcp.json" "$tmp_file"
            else
                python3 "$SCRIPTS_DIR/merge-configs.py" --type mcp --output "$target/.mcp.json" \
                    "$tmp_file"
            fi

            rm -f "$tmp_file"

            local servers_json
            servers_json=$(echo "$server_names" | python3 -c "
import json, sys
names = [l.strip() for l in sys.stdin if l.strip()]
print(json.dumps(names))
")
            state=$(echo "$state" | python3 -c "
import json, sys
state = json.load(sys.stdin)
ec = state.setdefault('external_components', {})
mcps = ec.setdefault('mcps', [])
entry = {'name': '$comp_name', 'source': '$comp_path', 'servers_added': $servers_json}
mcps = [m for m in mcps if m['name'] != '$comp_name']
mcps.append(entry)
ec['mcps'] = mcps
print(json.dumps(state, indent=2))
")
            ;;
        hook)
            # Download hook JSON, merge into settings, and install companion scripts
            local tmp_file="/tmp/ext-hook-${comp_name}.json"
            download_file "$github_path" "$tmp_file" || return 1

            # Extract hook config and any companion scripts
            python3 -c "
import json, sys, os

with open('$tmp_file') as f:
    data = json.load(f)

# If the hook contains a settings section with hooks, merge it
settings_part = {}
if 'hooks' in data:
    settings_part = {'hooks': data['hooks']}
elif 'settings' in data:
    settings_part = data['settings']

if settings_part:
    # Write a temp settings file for merging
    with open('/tmp/ext-hook-settings-${comp_name}.json', 'w') as f:
        json.dump(settings_part, f, indent=2)

# If there are script contents, write them
scripts = data.get('scripts', {})
for script_name, script_content in scripts.items():
    script_path = '$target/.claude/hooks/ext--${comp_name}--' + script_name
    os.makedirs(os.path.dirname(script_path), exist_ok=True)
    with open(script_path, 'w') as f:
        f.write(script_content)
    os.chmod(script_path, 0o755)
    print(f'Installed hook script: ext--${comp_name}--{script_name}')
" 2>/dev/null

            # Merge hook settings if they exist
            if [ -f "/tmp/ext-hook-settings-${comp_name}.json" ]; then
                if [ -f "$target/.claude/settings.json" ]; then
                    python3 "$SCRIPTS_DIR/merge-configs.py" --type settings --output "$target/.claude/settings.json" \
                        "$target/.claude/settings.json" "/tmp/ext-hook-settings-${comp_name}.json"
                else
                    mkdir -p "$target/.claude"
                    cp "/tmp/ext-hook-settings-${comp_name}.json" "$target/.claude/settings.json"
                fi
                rm -f "/tmp/ext-hook-settings-${comp_name}.json"
            fi

            rm -f "$tmp_file"

            state=$(echo "$state" | python3 -c "
import json, sys
state = json.load(sys.stdin)
ec = state.setdefault('external_components', {})
hooks = ec.setdefault('hooks', [])
entry = {'name': '$comp_name', 'source': '$comp_path', 'installed_to': '.claude/hooks/'}
hooks = [h for h in hooks if h['name'] != '$comp_name']
hooks.append(entry)
ec['hooks'] = hooks
print(json.dumps(state, indent=2))
")
            ;;
        setting)
            # Download settings JSON and merge into .claude/settings.json
            local tmp_file="/tmp/ext-setting-${comp_name}.json"
            download_file "$github_path" "$tmp_file" || return 1

            if [ -f "$target/.claude/settings.json" ]; then
                python3 "$SCRIPTS_DIR/merge-configs.py" --type settings --output "$target/.claude/settings.json" \
                    "$target/.claude/settings.json" "$tmp_file"
            else
                mkdir -p "$target/.claude"
                cp "$tmp_file" "$target/.claude/settings.json"
            fi

            rm -f "$tmp_file"

            # Track which keys were added
            local keys_json
            keys_json=$(python3 -c "
import json
with open('$CACHE_DIR/$github_path' if __import__('os').path.exists('$CACHE_DIR/$github_path') else '/dev/null') as f:
    try:
        data = json.load(f)
        print(json.dumps(list(data.keys())))
    except:
        print('[]')
" 2>/dev/null)

            state=$(echo "$state" | python3 -c "
import json, sys
state = json.load(sys.stdin)
ec = state.setdefault('external_components', {})
settings = ec.setdefault('settings', [])
entry = {'name': '$comp_name', 'source': '$comp_path', 'keys_added': $keys_json}
settings = [s for s in settings if s['name'] != '$comp_name']
settings.append(entry)
ec['settings'] = settings
print(json.dumps(state, indent=2))
")
            ;;
    esac

    write_state "$target" "$state"
    return 0
}

# --- Remove a single component ---

remove_component() {
    local target="$1"
    local comp_type="$2"    # agent, command, skill, mcp, hook, setting
    local comp_name="$3"    # just the name (not category/name)

    local state
    state=$(read_state "$target")

    case "$comp_type" in
        agent)
            local file="$target/.claude/agents/ext--${comp_name}.md"
            [ -f "$file" ] && rm "$file" && info "  Removed: agents/ext--${comp_name}.md"
            state=$(echo "$state" | python3 -c "
import json, sys
state = json.load(sys.stdin)
ec = state.get('external_components', {})
ec['agents'] = [a for a in ec.get('agents', []) if a['name'] != '$comp_name']
state['external_components'] = ec
print(json.dumps(state, indent=2))
")
            ;;
        command)
            local file="$target/.claude/commands/ext--${comp_name}.md"
            [ -f "$file" ] && rm "$file" && info "  Removed: commands/ext--${comp_name}.md"
            state=$(echo "$state" | python3 -c "
import json, sys
state = json.load(sys.stdin)
ec = state.get('external_components', {})
ec['commands'] = [c for c in ec.get('commands', []) if c['name'] != '$comp_name']
state['external_components'] = ec
print(json.dumps(state, indent=2))
")
            ;;
        skill)
            local dir="$target/.claude/skills/ext--${comp_name}"
            [ -d "$dir" ] && rm -rf "$dir" && info "  Removed: skills/ext--${comp_name}/"
            state=$(echo "$state" | python3 -c "
import json, sys
state = json.load(sys.stdin)
ec = state.get('external_components', {})
ec['skills'] = [s for s in ec.get('skills', []) if s['name'] != '$comp_name']
state['external_components'] = ec
print(json.dumps(state, indent=2))
")
            ;;
        mcp)
            # Remove tracked servers from .mcp.json
            if [ -f "$target/.mcp.json" ]; then
                state=$(echo "$state" | python3 -c "
import json, sys

state = json.load(sys.stdin)
ec = state.get('external_components', {})
mcps = ec.get('mcps', [])

# Find the servers to remove
servers_to_remove = []
for m in mcps:
    if m['name'] == '$comp_name':
        servers_to_remove = m.get('servers_added', [])
        break

# Remove servers from .mcp.json
try:
    with open('$target/.mcp.json') as f:
        mcp_config = json.load(f)
    for srv in servers_to_remove:
        mcp_config.get('mcpServers', {}).pop(srv, None)
    with open('$target/.mcp.json', 'w') as f:
        json.dump(mcp_config, f, indent=2)
        f.write('\n')
except FileNotFoundError:
    pass

ec['mcps'] = [m for m in mcps if m['name'] != '$comp_name']
state['external_components'] = ec
print(json.dumps(state, indent=2))
")
                info "  Removed MCP servers for: $comp_name"
            fi
            ;;
        hook)
            # Remove hook scripts with ext--name-- prefix
            for script in "$target/.claude/hooks/ext--${comp_name}--"*; do
                [ -f "$script" ] && rm "$script" && info "  Removed: hooks/$(basename "$script")"
            done
            state=$(echo "$state" | python3 -c "
import json, sys
state = json.load(sys.stdin)
ec = state.get('external_components', {})
ec['hooks'] = [h for h in ec.get('hooks', []) if h['name'] != '$comp_name']
state['external_components'] = ec
print(json.dumps(state, indent=2))
")
            ;;
        setting)
            # Settings were merged in; we track the name but removal requires re-merging
            # from local overlays only (handled by deactivate.sh or manual re-activation)
            warn "Setting '$comp_name' was merged into settings.json. Re-activate to restore clean state."
            state=$(echo "$state" | python3 -c "
import json, sys
state = json.load(sys.stdin)
ec = state.get('external_components', {})
ec['settings'] = [s for s in ec.get('settings', []) if s['name'] != '$comp_name']
state['external_components'] = ec
print(json.dumps(state, indent=2))
")
            ;;
    esac

    write_state "$target" "$state"
}

# --- Catalog browsing ---

cmd_catalog() {
    ensure_catalog

    local filter_type=""
    local search_term=""

    while [ $# -gt 0 ]; do
        case "$1" in
            --type) filter_type="$2"; shift 2 ;;
            --search) search_term="$2"; shift 2 ;;
            *) error "Unknown catalog option: $1" ;;
        esac
    done

    python3 -c "
import json, sys

with open('$CATALOG_FILE') as f:
    catalog = json.load(f)

filter_type = '$filter_type'
search_term = '$search_term'.lower()

# Map singular to plural
type_map = {
    'agent': 'agents', 'command': 'commands', 'skill': 'skills',
    'mcp': 'mcps', 'hook': 'hooks', 'setting': 'settings'
}

types_to_show = list(catalog['components'].keys())
if filter_type:
    plural = type_map.get(filter_type, filter_type)
    if plural in catalog['components']:
        types_to_show = [plural]
    else:
        print(f'Unknown type: {filter_type}', file=sys.stderr)
        sys.exit(1)

total = 0
for comp_type in types_to_show:
    items = catalog['components'].get(comp_type, [])
    if search_term:
        items = [i for i in items if search_term in i['name'].lower() or search_term in i['category'].lower() or search_term in i['path'].lower()]
    if not items:
        continue

    print(f'\n\033[1m{comp_type.upper()}\033[0m ({len(items)} components):')
    # Group by category
    by_cat = {}
    for item in items:
        by_cat.setdefault(item['category'], []).append(item)
    for cat in sorted(by_cat):
        names = sorted(i['name'] for i in by_cat[cat])
        print(f'  {cat}/')
        for name in names:
            print(f'    {name}')
            total += 1

print(f'\n{total} component(s) shown.')
if search_term:
    print(f'(filtered by: \"{search_term}\")')
print(f'Source: {catalog[\"source\"]} (synced {catalog[\"fetched_at\"]})')
"
}

# --- Install subcommand ---

cmd_install() {
    [ $# -lt 1 ] && error "Missing target path. Usage: $0 install <target-path> OPTIONS"

    local target
    target="$(cd "$1" 2>/dev/null && pwd)" || error "Target directory not found: $1"
    shift

    ensure_catalog

    local agents=() commands=() skills=() mcps=() hooks=() settings=()
    local recommended=false

    while [ $# -gt 0 ]; do
        case "$1" in
            --agent) agents+=("$2"); shift 2 ;;
            --command) commands+=("$2"); shift 2 ;;
            --skill) skills+=("$2"); shift 2 ;;
            --mcp) mcps+=("$2"); shift 2 ;;
            --hook) hooks+=("$2"); shift 2 ;;
            --setting) settings+=("$2"); shift 2 ;;
            --recommended) recommended=true; shift ;;
            *) error "Unknown install option: $1" ;;
        esac
    done

    if $recommended; then
        info "Installing overlay-recommended external components..."
        local state
        state=$(read_state "$target")

        # Get active overlays from state
        local active_overlays
        active_overlays=$(echo "$state" | python3 -c "
import json, sys
state = json.load(sys.stdin)
for o in state.get('overlays', []):
    print(o)
" 2>/dev/null)

        if [ -z "$active_overlays" ]; then
            warn "No active overlays found. Activate overlays first, then use --recommended."
            return 1
        fi

        # Read recommended_external from each overlay
        while IFS= read -r overlay; do
            local overlay_json="$REPO_DIR/overlays/$overlay/overlay.json"
            [ -f "$overlay_json" ] || continue

            python3 -c "
import json
with open('$overlay_json') as f:
    data = json.load(f)
rec = data.get('recommended_external', {})
for comp_type, paths in rec.items():
    for path in paths:
        print(f'{comp_type}|{path}')
" 2>/dev/null | while IFS='|' read -r rec_type rec_path; do
                # Map plural to singular
                local singular="${rec_type%s}"
                info "  Recommended ($overlay): $singular $rec_path"
                install_component "$target" "$singular" "$rec_path" || true
            done
        done <<< "$active_overlays"

        return 0
    fi

    local installed=0

    for path in "${agents[@]}"; do
        info "Installing agent: $path"
        if install_component "$target" "agent" "$path"; then installed=$((installed + 1)); fi
    done
    for path in "${commands[@]}"; do
        info "Installing command: $path"
        if install_component "$target" "command" "$path"; then installed=$((installed + 1)); fi
    done
    for path in "${skills[@]}"; do
        info "Installing skill: $path"
        if install_component "$target" "skill" "$path"; then installed=$((installed + 1)); fi
    done
    for path in "${mcps[@]}"; do
        info "Installing MCP: $path"
        if install_component "$target" "mcp" "$path"; then installed=$((installed + 1)); fi
    done
    for path in "${hooks[@]}"; do
        info "Installing hook: $path"
        if install_component "$target" "hook" "$path"; then installed=$((installed + 1)); fi
    done
    for path in "${settings[@]}"; do
        info "Installing setting: $path"
        if install_component "$target" "setting" "$path"; then installed=$((installed + 1)); fi
    done

    if [ "$installed" -eq 0 ]; then
        warn "No components were installed. Specify at least one --agent, --command, --skill, --mcp, --hook, or --setting."
        return 1
    fi

    info "Installed $installed external component(s) to $target"
}

# --- Remove subcommand ---

cmd_remove() {
    [ $# -lt 1 ] && error "Missing target path. Usage: $0 remove <target-path> OPTIONS"

    local target
    target="$(cd "$1" 2>/dev/null && pwd)" || error "Target directory not found: $1"
    shift

    local removed=0

    while [ $# -gt 0 ]; do
        case "$1" in
            --agent) info "Removing agent: $2"; remove_component "$target" "agent" "$2"; removed=$((removed + 1)); shift 2 ;;
            --command) info "Removing command: $2"; remove_component "$target" "command" "$2"; removed=$((removed + 1)); shift 2 ;;
            --skill) info "Removing skill: $2"; remove_component "$target" "skill" "$2"; removed=$((removed + 1)); shift 2 ;;
            --mcp) info "Removing MCP: $2"; remove_component "$target" "mcp" "$2"; removed=$((removed + 1)); shift 2 ;;
            --hook) info "Removing hook: $2"; remove_component "$target" "hook" "$2"; removed=$((removed + 1)); shift 2 ;;
            --setting) info "Removing setting: $2"; remove_component "$target" "setting" "$2"; removed=$((removed + 1)); shift 2 ;;
            *) error "Unknown remove option: $1" ;;
        esac
    done

    [ "$removed" -eq 0 ] && warn "Nothing to remove. Specify --agent, --command, --skill, --mcp, --hook, or --setting."
    info "Removed $removed external component(s) from $target"
}

# --- Main dispatch ---

SUBCOMMAND="$1"
shift

case "$SUBCOMMAND" in
    catalog)      cmd_catalog "$@" ;;
    install)      cmd_install "$@" ;;
    remove)       cmd_remove "$@" ;;
    sync-catalog) exec "$SCRIPTS_DIR/sync-catalog.sh" ;;
    *)            error "Unknown subcommand: $SUBCOMMAND"; usage ;;
esac
