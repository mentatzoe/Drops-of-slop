#!/usr/bin/env bash
# browse-catalog.sh — Interactive browser for the external component catalog.
#
# Usage:
#   ./scripts/browse-catalog.sh <target-path>                          Interactive (full menu loop)
#   ./scripts/browse-catalog.sh <target-path> --recommended            Show recommendations, prompt for selection
#   ./scripts/browse-catalog.sh <target-path> --recommended --auto     Auto-install all recommended (non-interactive)
#   ./scripts/browse-catalog.sh <target-path> --search "frontend"      Jump to search
#   ./scripts/browse-catalog.sh <target-path> --type agent             Browse a specific type
#   ./scripts/browse-catalog.sh <target-path> --no-fzf                 Force numbered menus (skip fzf)
#   ./scripts/browse-catalog.sh <target-path> --no-color               Disable colored output

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
CATALOG_FILE="$REPO_DIR/external-catalog.json"
SCRIPTS_DIR="$REPO_DIR/scripts"
OVERLAYS_DIR="$REPO_DIR/overlays"

# --- Colors ---

RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
BOLD=$'\033[1m'
DIM=$'\033[2m'
NC=$'\033[0m'

error() { echo -e "${RED}ERROR:${NC} $1" >&2; exit 1; }
warn()  { echo -e "${YELLOW}WARN:${NC} $1" >&2; }
info()  { echo -e "${GREEN}>>>${NC} $1"; }

# --- Argument parsing ---

usage() {
    cat <<EOF
Usage: $(basename "$0") <target-path> [OPTIONS]

Browse and install external components from the catalog.

Options:
  --recommended       Show only overlay-recommended components
  --auto              Auto-install all recommended (non-interactive, use with --recommended)
  --search <term>     Jump straight to search results
  --type <type>       Browse a specific component type (agent|command|skill|mcp|hook|setting)
  --no-fzf            Force numbered menus even if fzf is available
  --no-color          Disable colored output
EOF
    exit 1
}

[ $# -lt 1 ] && usage

TARGET="$(cd "$1" 2>/dev/null && pwd)" || error "Target directory not found: $1"
shift

MODE="interactive"  # interactive | recommended | search | type
AUTO=false
SEARCH_TERM=""
FILTER_TYPE=""
USE_FZF=true
NO_COLOR=false

while [ $# -gt 0 ]; do
    case "$1" in
        --recommended) MODE="recommended"; shift ;;
        --auto)        AUTO=true; shift ;;
        --search)      MODE="search"; SEARCH_TERM="$2"; shift 2 ;;
        --type)        MODE="type"; FILTER_TYPE="$2"; shift 2 ;;
        --no-fzf)      USE_FZF=false; shift ;;
        --no-color)    NO_COLOR=true; shift ;;
        -*)            error "Unknown option: $1" ;;
        *)             error "Unexpected argument: $1" ;;
    esac
done

if $NO_COLOR; then
    RED='' GREEN='' YELLOW='' BLUE='' BOLD='' DIM='' NC=''
fi

STATE_FILE="$TARGET/.claude/.activated-overlays.json"

# Detect fzf
HAS_FZF=false
if $USE_FZF && command -v fzf &>/dev/null; then
    HAS_FZF=true
fi

# Ensure catalog exists
if [ ! -f "$CATALOG_FILE" ]; then
    warn "No catalog found. Running sync first..."
    "$SCRIPTS_DIR/sync-catalog.sh" || error "Failed to sync catalog"
fi

# ============================================================================
# Data functions (inline Python for JSON manipulation)
# ============================================================================

get_active_overlays() {
    # Outputs overlay names, one per line
    if [ ! -f "$STATE_FILE" ]; then
        return
    fi
    python3 -c "
import json, sys
try:
    with open('$STATE_FILE') as f:
        state = json.load(f)
    for o in state.get('overlays', []):
        print(o)
except:
    pass
" 2>/dev/null
}

get_recommended_components() {
    # Outputs: type|path|overlay  (deduplicated by type+path)
    local overlays
    overlays=$(get_active_overlays)
    [ -z "$overlays" ] && return

    echo "$overlays" | python3 -c "
import json, sys, os

overlays = [l.strip() for l in sys.stdin if l.strip()]
seen = set()
overlays_dir = '$OVERLAYS_DIR'

for overlay in overlays:
    overlay_json = os.path.join(overlays_dir, overlay, 'overlay.json')
    if not os.path.isfile(overlay_json):
        continue
    with open(overlay_json) as f:
        data = json.load(f)
    rec = data.get('recommended_external', {})
    for comp_type, paths in rec.items():
        singular = comp_type.rstrip('s')
        for path in paths:
            key = f'{singular}|{path}'
            if key not in seen:
                seen.add(key)
                print(f'{singular}|{path}|{overlay}')
" 2>/dev/null
}

get_installed_components() {
    # Outputs: type|name|source
    if [ ! -f "$STATE_FILE" ]; then
        return
    fi
    python3 -c "
import json
try:
    with open('$STATE_FILE') as f:
        state = json.load(f)
    ec = state.get('external_components', {})
    for comp_type in ['agents', 'commands', 'skills', 'mcps', 'hooks', 'settings']:
        singular = comp_type.rstrip('s')
        for item in ec.get(comp_type, []):
            source = item.get('source', item.get('name', ''))
            print(f'{singular}|{item[\"name\"]}|{source}')
except:
    pass
" 2>/dev/null
}

get_installed_set() {
    # Outputs: type:source lines for quick lookup
    if [ ! -f "$STATE_FILE" ]; then
        return
    fi
    python3 -c "
import json
try:
    with open('$STATE_FILE') as f:
        state = json.load(f)
    ec = state.get('external_components', {})
    for comp_type in ['agents', 'commands', 'skills', 'mcps', 'hooks', 'settings']:
        singular = comp_type.rstrip('s')
        for item in ec.get(comp_type, []):
            source = item.get('source', '')
            if source:
                print(f'{singular}:{source}')
except:
    pass
" 2>/dev/null
}

get_catalog_types() {
    # Outputs: type|count
    python3 -c "
import json
with open('$CATALOG_FILE') as f:
    catalog = json.load(f)
for comp_type in sorted(catalog.get('components', {}).keys()):
    count = len(catalog['components'][comp_type])
    singular = comp_type.rstrip('s')
    print(f'{singular}|{count}')
" 2>/dev/null
}

get_categories_for_type() {
    # Outputs: category|count
    local comp_type="$1"  # singular: agent, command, etc.
    local plural="${comp_type}s"
    python3 -c "
import json
with open('$CATALOG_FILE') as f:
    catalog = json.load(f)
items = catalog.get('components', {}).get('$plural', [])
cats = {}
for item in items:
    cat = item.get('category', 'uncategorized')
    cats[cat] = cats.get(cat, 0) + 1
for cat in sorted(cats):
    print(f'{cat}|{cats[cat]}')
" 2>/dev/null
}

get_components_in_category() {
    # Outputs: name|path|installed_flag (1 or 0)
    local comp_type="$1"  # singular
    local category="$2"
    local plural="${comp_type}s"
    local installed_set="$3"  # newline-separated type:source pairs

    echo "$installed_set" | python3 -c "
import json, sys

installed = set()
for line in sys.stdin:
    line = line.strip()
    if line:
        installed.add(line)

with open('$CATALOG_FILE') as f:
    catalog = json.load(f)

items = catalog.get('components', {}).get('$plural', [])
for item in items:
    if item.get('category') == '$category':
        key = '$comp_type' + ':' + item['path']
        flag = '1' if key in installed else '0'
        print(f'{item[\"name\"]}|{item[\"path\"]}|{flag}')
" 2>/dev/null
}

search_catalog() {
    # Outputs: type|name|path|installed_flag
    local term="$1"
    local installed_set="$2"

    echo "$installed_set" | python3 -c "
import json, sys

installed = set()
for line in sys.stdin:
    line = line.strip()
    if line:
        installed.add(line)

term = '''$term'''.lower()
with open('$CATALOG_FILE') as f:
    catalog = json.load(f)

for comp_type in sorted(catalog.get('components', {}).keys()):
    singular = comp_type.rstrip('s')
    for item in catalog['components'][comp_type]:
        if (term in item['name'].lower() or
            term in item.get('category', '').lower() or
            term in item['path'].lower()):
            key = singular + ':' + item['path']
            flag = '1' if key in installed else '0'
            print(f'{singular}|{item[\"name\"]}|{item[\"path\"]}|{flag}')
" 2>/dev/null
}

get_catalog_total() {
    python3 -c "
import json
with open('$CATALOG_FILE') as f:
    catalog = json.load(f)
total = sum(len(v) for v in catalog.get('components', {}).values())
print(total)
" 2>/dev/null
}

# ============================================================================
# UI helpers
# ============================================================================

clear_screen() {
    printf '\033[2J\033[H'
}

print_header() {
    local overlays installed_count catalog_total
    overlays=$(get_active_overlays | tr '\n' ', ' | sed 's/,$//' | sed 's/,/, /g')
    installed_count=$(get_installed_components | wc -l | tr -d ' ')
    catalog_total=$(get_catalog_total)

    echo ""
    echo -e "${BOLD}============================================${NC}"
    echo -e "${BOLD}Claude Templates - External Component Browser${NC}"
    echo -e "  Target:   ${BLUE}$TARGET${NC}"
    if [ -n "$overlays" ]; then
        echo -e "  Overlays: ${GREEN}$overlays${NC}"
    else
        echo -e "  Overlays: ${DIM}(none active)${NC}"
    fi
    echo -e "  Catalog:  $catalog_total components"
    echo -e "  Installed externals: $installed_count component(s)"
    echo -e "${BOLD}============================================${NC}"
    echo ""
}

# Parse user selection like "1,3,5-7" into an array of 0-based indices
parse_selection() {
    local input="$1"
    local max="$2"
    local -n _result=$3

    _result=()

    # Split on commas
    IFS=',' read -ra parts <<< "$input"
    for part in "${parts[@]}"; do
        part=$(echo "$part" | tr -d ' ')
        if [[ "$part" == *-* ]]; then
            # Range: "5-7"
            local start end
            start="${part%-*}"
            end="${part#*-}"
            if [[ "$start" =~ ^[0-9]+$ ]] && [[ "$end" =~ ^[0-9]+$ ]]; then
                for (( i=start; i<=end && i<=max; i++ )); do
                    if [ "$i" -ge 1 ]; then
                        _result+=($((i - 1)))
                    fi
                done
            fi
        elif [[ "$part" =~ ^[0-9]+$ ]] && [ "$part" -ge 1 ] && [ "$part" -le "$max" ]; then
            _result+=($((part - 1)))
        fi
    done
}

# Show a numbered list with [x]/[ ] checkboxes. Returns selected items.
# Input: array of "label|value|installed_flag" lines
# Output: selected values written to the provided array variable
show_selection_menu() {
    local -n _items=$1
    local -n _selected=$2
    local prompt_text="${3:-Select (e.g., 1,3,5-7), 'a' for all uninstalled, 'b' to go back}"

    _selected=()
    local count=${#_items[@]}

    if [ "$count" -eq 0 ]; then
        echo -e "  ${DIM}(no items)${NC}"
        return
    fi

    # If fzf available and more than 10 items, use fzf
    if $HAS_FZF && [ "$count" -gt 10 ]; then
        local fzf_input=""
        for i in "${!_items[@]}"; do
            IFS='|' read -r label value flag <<< "${_items[$i]}"
            local marker="[ ]"
            [ "$flag" = "1" ] && marker="[x]"
            fzf_input+="$marker  $((i+1)). $label"$'\n'
        done

        local fzf_result
        fzf_result=$(echo -n "$fzf_input" | fzf --multi --ansi --prompt="Select components (TAB to multi-select): " --header="$prompt_text" 2>/dev/null) || true

        if [ -n "$fzf_result" ]; then
            while IFS= read -r line; do
                # Extract the index number
                local idx
                idx=$(echo "$line" | sed -E 's/^\[.\]  ([0-9]+)\..*/\1/')
                if [[ "$idx" =~ ^[0-9]+$ ]]; then
                    local item="${_items[$((idx-1))]}"
                    IFS='|' read -r _ value flag <<< "$item"
                    if [ "$flag" != "1" ]; then
                        _selected+=("$value")
                    fi
                fi
            done <<< "$fzf_result"
        fi
        return
    fi

    # Numbered menu
    for i in "${!_items[@]}"; do
        IFS='|' read -r label value flag <<< "${_items[$i]}"
        local marker="[ ]"
        local suffix=""
        if [ "$flag" = "1" ]; then
            marker="${GREEN}[x]${NC}"
            suffix=" ${DIM}(already installed)${NC}"
        fi
        printf "    %s %2d. %s%s\n" "$marker" "$((i+1))" "$label" "$suffix"
    done

    echo ""
    echo -e "  $prompt_text"
    local choice
    read -r -p "  > " choice || choice="b"

    if [ "$choice" = "b" ] || [ "$choice" = "B" ]; then
        return
    fi

    if [ "$choice" = "a" ] || [ "$choice" = "A" ]; then
        # Select all uninstalled
        for i in "${!_items[@]}"; do
            IFS='|' read -r _ value flag <<< "${_items[$i]}"
            if [ "$flag" != "1" ]; then
                _selected+=("$value")
            fi
        done
        return
    fi

    # Parse selection
    local indices=()
    parse_selection "$choice" "$count" indices

    for idx in "${indices[@]}"; do
        IFS='|' read -r _ value flag <<< "${_items[$idx]}"
        if [ "$flag" != "1" ]; then
            _selected+=("$value")
        fi
    done
}

# ============================================================================
# Install / Remove
# ============================================================================

# Takes an array of "type|path" entries, confirms, then installs
do_install() {
    local -n _to_install=$1
    local auto="${2:-false}"

    if [ ${#_to_install[@]} -eq 0 ]; then
        echo -e "  ${DIM}Nothing to install.${NC}"
        echo ""
        return
    fi

    echo ""
    echo -e "  ${BOLD}About to install ${#_to_install[@]} component(s):${NC}"
    for entry in "${_to_install[@]}"; do
        IFS='|' read -r itype ipath <<< "$entry"
        printf "    [%-7s] %s\n" "$itype" "$ipath"
    done

    if ! $auto; then
        echo ""
        local confirm
        read -r -p "  Proceed? [Y/n]: " confirm || confirm="n"
        if [[ "$confirm" =~ ^[nN] ]]; then
            echo "  Cancelled."
            return
        fi
    fi

    echo ""
    local installed=0
    for entry in "${_to_install[@]}"; do
        IFS='|' read -r itype ipath <<< "$entry"
        info "Installing $itype: $ipath"
        if "$SCRIPTS_DIR/fetch-external.sh" install "$TARGET" "--$itype" "$ipath" 2>&1; then
            installed=$((installed + 1))
        else
            warn "Failed to install $itype: $ipath"
        fi
    done

    echo ""
    info "Installed $installed of ${#_to_install[@]} component(s)."
    echo ""

    if ! $auto; then
        read -r -p "  Press Enter to continue..." _ || true
    fi
}

do_remove() {
    local comp_type="$1"
    local comp_name="$2"

    echo ""
    local confirm
    read -r -p "  Remove $comp_type '$comp_name'? [y/N]: " confirm || confirm="n"
    if [[ ! "$confirm" =~ ^[yY] ]]; then
        echo "  Cancelled."
        return
    fi

    "$SCRIPTS_DIR/fetch-external.sh" remove "$TARGET" "--$comp_type" "$comp_name" 2>&1
    echo ""
    info "Removed $comp_type: $comp_name"
    read -r -p "  Press Enter to continue..." _ || true
}

# ============================================================================
# Screen functions
# ============================================================================

screen_recommendations() {
    local installed_set
    installed_set=$(get_installed_set)

    local recs
    recs=$(get_recommended_components)

    if [ -z "$recs" ]; then
        echo -e "  ${DIM}No recommendations available.${NC}"
        echo -e "  ${DIM}(Activate overlays with recommended_external to see suggestions)${NC}"
        echo ""
        if ! $AUTO; then
            read -r -p "  Press Enter to continue..." _ || true
        fi
        return
    fi

    # Group recommendations by overlay
    local current_overlay=""
    local menu_items=()
    local all_values=()

    while IFS='|' read -r rtype rpath roverlay; do
        if [ "$roverlay" != "$current_overlay" ]; then
            if [ -n "$current_overlay" ]; then
                echo ""
            fi
            current_overlay="$roverlay"
            echo -e "  ${BOLD}Recommended for [${GREEN}$roverlay${NC}${BOLD}]:${NC}"
        fi

        # Check if installed
        local flag="0"
        if echo "$installed_set" | grep -qF "$rtype:$rpath"; then
            flag="1"
        fi

        local label="[${rtype}]   ${rpath}"
        menu_items+=("${label}|${rtype}|${rpath}|${flag}")
    done <<< "$recs"

    # Build selection items (label|value|flag format)
    local sel_items=()
    for entry in "${menu_items[@]}"; do
        IFS='|' read -r label etype epath eflag <<< "$entry"
        sel_items+=("$label|${etype}|${epath}|${eflag}")
    done

    if $AUTO; then
        # Auto mode: install all uninstalled
        local to_install=()
        for entry in "${menu_items[@]}"; do
            IFS='|' read -r _ etype epath eflag <<< "$entry"
            if [ "$eflag" != "1" ]; then
                to_install+=("${etype}|${epath}")
            fi
        done
        do_install to_install true
        return
    fi

    # Show numbered list with selection
    echo ""
    local count=0
    local display_items=()
    for entry in "${menu_items[@]}"; do
        IFS='|' read -r label etype epath eflag <<< "$entry"
        count=$((count + 1))
        display_items+=("${label}|${etype}|${epath}|${eflag}")

        local marker="[ ]"
        local suffix=""
        if [ "$eflag" = "1" ]; then
            marker="${GREEN}[x]${NC}"
            suffix=" ${DIM}(already installed)${NC}"
        fi
        printf "    %s %2d. %s%s\n" "$marker" "$count" "$label" "$suffix"
    done

    echo ""
    echo -e "  Select (e.g., 2,3,5-7), 'a' for all uninstalled, 'b' to go back:"
    local choice
    read -r -p "  > " choice || choice="b"

    if [ "$choice" = "b" ] || [ "$choice" = "B" ]; then
        return
    fi

    local to_install=()

    if [ "$choice" = "a" ] || [ "$choice" = "A" ]; then
        for entry in "${display_items[@]}"; do
            IFS='|' read -r _ etype epath eflag <<< "$entry"
            if [ "$eflag" != "1" ]; then
                to_install+=("${etype}|${epath}")
            fi
        done
    else
        local indices=()
        parse_selection "$choice" "$count" indices
        for idx in "${indices[@]}"; do
            IFS='|' read -r _ etype epath eflag <<< "${display_items[$idx]}"
            if [ "$eflag" != "1" ]; then
                to_install+=("${etype}|${epath}")
            fi
        done
    fi

    do_install to_install false
}

screen_browse_type() {
    while true; do
        clear_screen
        echo ""
        echo -e "  ${BOLD}Browse by Type${NC}"
        echo ""

        local types=()
        while IFS='|' read -r tname tcount; do
            types+=("$tname|$tcount")
        done < <(get_catalog_types)

        if [ ${#types[@]} -eq 0 ]; then
            echo -e "  ${DIM}(catalog is empty)${NC}"
            read -r -p "  Press Enter to continue..." _ || true
            return
        fi

        for i in "${!types[@]}"; do
            IFS='|' read -r tname tcount <<< "${types[$i]}"
            printf "    %2d) %-10s (%d components)\n" "$((i+1))" "$tname" "$tcount"
        done
        echo ""
        echo "     b) Back to main menu"
        echo ""

        local choice
        read -r -p "  > " choice || choice="b"

        if [ "$choice" = "b" ] || [ "$choice" = "B" ]; then
            return
        fi

        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#types[@]} ]; then
            local selected="${types[$((choice-1))]}"
            IFS='|' read -r sel_type _ <<< "$selected"
            screen_browse_categories "$sel_type"
        fi
    done
}

screen_browse_categories() {
    local comp_type="$1"  # singular

    while true; do
        clear_screen
        echo ""
        echo -e "  ${BOLD}Browse: ${GREEN}${comp_type}s${NC}"
        echo ""

        local cats=()
        while IFS='|' read -r cname ccount; do
            cats+=("$cname|$ccount")
        done < <(get_categories_for_type "$comp_type")

        if [ ${#cats[@]} -eq 0 ]; then
            echo -e "  ${DIM}(no categories)${NC}"
            read -r -p "  Press Enter to continue..." _ || true
            return
        fi

        for i in "${!cats[@]}"; do
            IFS='|' read -r cname ccount <<< "${cats[$i]}"
            printf "    %2d) %-30s (%d)\n" "$((i+1))" "$cname" "$ccount"
        done
        echo ""
        echo "     b) Back"
        echo ""

        local choice
        read -r -p "  > " choice || choice="b"

        if [ "$choice" = "b" ] || [ "$choice" = "B" ]; then
            return
        fi

        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#cats[@]} ]; then
            local selected="${cats[$((choice-1))]}"
            IFS='|' read -r sel_cat _ <<< "$selected"
            screen_browse_components "$comp_type" "$sel_cat"
        fi
    done
}

screen_browse_components() {
    local comp_type="$1"  # singular
    local category="$2"

    clear_screen
    echo ""
    echo -e "  ${BOLD}${comp_type}s / ${GREEN}$category${NC}"
    echo ""

    local installed_set
    installed_set=$(get_installed_set)

    local items=()
    while IFS='|' read -r cname cpath cflag; do
        local label="[$comp_type] $cpath"
        items+=("${label}|${comp_type}|${cpath}|${cflag}")
    done < <(get_components_in_category "$comp_type" "$category" "$installed_set")

    if [ ${#items[@]} -eq 0 ]; then
        echo -e "  ${DIM}(no components in this category)${NC}"
        read -r -p "  Press Enter to continue..." _ || true
        return
    fi

    local count=${#items[@]}
    for i in "${!items[@]}"; do
        IFS='|' read -r label _ _ cflag <<< "${items[$i]}"
        local marker="[ ]"
        local suffix=""
        if [ "$cflag" = "1" ]; then
            marker="${GREEN}[x]${NC}"
            suffix=" ${DIM}(already installed)${NC}"
        fi
        printf "    %s %2d. %s%s\n" "$marker" "$((i+1))" "$label" "$suffix"
    done

    echo ""
    echo -e "  Select (e.g., 1,3,5-7), 'a' for all uninstalled, 'b' to go back:"
    local choice
    read -r -p "  > " choice || choice="b"

    if [ "$choice" = "b" ] || [ "$choice" = "B" ]; then
        return
    fi

    local to_install=()

    if [ "$choice" = "a" ] || [ "$choice" = "A" ]; then
        for entry in "${items[@]}"; do
            IFS='|' read -r _ etype epath eflag <<< "$entry"
            if [ "$eflag" != "1" ]; then
                to_install+=("${etype}|${epath}")
            fi
        done
    else
        local indices=()
        parse_selection "$choice" "$count" indices
        for idx in "${indices[@]}"; do
            IFS='|' read -r _ etype epath eflag <<< "${items[$idx]}"
            if [ "$eflag" != "1" ]; then
                to_install+=("${etype}|${epath}")
            fi
        done
    fi

    do_install to_install false
}

screen_search() {
    local term="${1:-}"

    if [ -z "$term" ]; then
        echo ""
        read -r -p "  Search catalog: " term || return
    fi

    if [ -z "$term" ]; then
        return
    fi

    clear_screen
    echo ""
    echo -e "  ${BOLD}Search results for: ${GREEN}\"$term\"${NC}"
    echo ""

    local installed_set
    installed_set=$(get_installed_set)

    local results=()
    while IFS='|' read -r rtype rname rpath rflag; do
        local label="[${rtype}]   ${rpath}"
        results+=("${label}|${rtype}|${rpath}|${rflag}")
    done < <(search_catalog "$term" "$installed_set")

    if [ ${#results[@]} -eq 0 ]; then
        echo -e "  ${DIM}No results found.${NC}"
        echo ""
        read -r -p "  Press Enter to continue..." _ || true
        return
    fi

    echo -e "  ${DIM}Found ${#results[@]} result(s)${NC}"
    echo ""

    local count=${#results[@]}
    for i in "${!results[@]}"; do
        IFS='|' read -r label _ _ rflag <<< "${results[$i]}"
        local marker="[ ]"
        local suffix=""
        if [ "$rflag" = "1" ]; then
            marker="${GREEN}[x]${NC}"
            suffix=" ${DIM}(already installed)${NC}"
        fi
        printf "    %s %2d. %s%s\n" "$marker" "$((i+1))" "$label" "$suffix"
    done

    echo ""
    echo -e "  Select (e.g., 1,3,5-7), 'a' for all uninstalled, 'b' to go back:"
    local choice
    read -r -p "  > " choice || choice="b"

    if [ "$choice" = "b" ] || [ "$choice" = "B" ]; then
        return
    fi

    local to_install=()

    if [ "$choice" = "a" ] || [ "$choice" = "A" ]; then
        for entry in "${results[@]}"; do
            IFS='|' read -r _ etype epath eflag <<< "$entry"
            if [ "$eflag" != "1" ]; then
                to_install+=("${etype}|${epath}")
            fi
        done
    else
        local indices=()
        parse_selection "$choice" "$count" indices
        for idx in "${indices[@]}"; do
            IFS='|' read -r _ etype epath eflag <<< "${results[$idx]}"
            if [ "$eflag" != "1" ]; then
                to_install+=("${etype}|${epath}")
            fi
        done
    fi

    do_install to_install false
}

screen_installed() {
    clear_screen
    echo ""
    echo -e "  ${BOLD}Installed External Components${NC}"
    echo ""

    local items=()
    while IFS='|' read -r itype iname isource; do
        items+=("$itype|$iname|$isource")
    done < <(get_installed_components)

    if [ ${#items[@]} -eq 0 ]; then
        echo -e "  ${DIM}No external components installed.${NC}"
        echo ""
        read -r -p "  Press Enter to continue..." _ || true
        return
    fi

    for i in "${!items[@]}"; do
        IFS='|' read -r itype iname isource <<< "${items[$i]}"
        printf "    %2d. [%-7s] %s  ${DIM}(%s)${NC}\n" "$((i+1))" "$itype" "$iname" "$isource"
    done

    echo ""
    echo -e "  Enter number to remove, 'b' to go back:"
    local choice
    read -r -p "  > " choice || choice="b"

    if [ "$choice" = "b" ] || [ "$choice" = "B" ]; then
        return
    fi

    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#items[@]} ]; then
        local selected="${items[$((choice-1))]}"
        IFS='|' read -r rtype rname _ <<< "$selected"
        do_remove "$rtype" "$rname"
    fi
}

# ============================================================================
# Main menu / dispatch
# ============================================================================

main_menu() {
    while true; do
        clear_screen
        print_header

        local rec_count
        rec_count=$(get_recommended_components | wc -l | tr -d ' ')

        echo "  1) Recommended for your overlays ($rec_count components)"
        echo "  2) Browse by type"
        echo "  3) Search catalog"
        echo "  4) View installed components"
        echo "  q) Quit"
        echo ""

        local choice
        read -r -p "  > " choice || choice="q"

        case "$choice" in
            1)
                clear_screen
                echo ""
                echo -e "  ${BOLD}Recommended Components${NC}"
                echo ""
                screen_recommendations
                ;;
            2)
                screen_browse_type
                ;;
            3)
                clear_screen
                screen_search
                ;;
            4)
                screen_installed
                ;;
            q|Q)
                echo ""
                info "Goodbye!"
                exit 0
                ;;
        esac
    done
}

# --- Main dispatch ---

case "$MODE" in
    recommended)
        if $AUTO; then
            screen_recommendations
        else
            echo ""
            echo -e "  ${BOLD}Recommended Components${NC}"
            echo ""
            screen_recommendations
        fi
        ;;
    search)
        screen_search "$SEARCH_TERM"
        ;;
    type)
        if [ -n "$FILTER_TYPE" ]; then
            screen_browse_categories "$FILTER_TYPE"
        else
            screen_browse_type
        fi
        ;;
    interactive)
        main_menu
        ;;
esac
