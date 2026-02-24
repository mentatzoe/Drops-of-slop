#!/usr/bin/env bash
# install.sh — Remote installer for claude-templates.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/mentatzoe/Drops-of-slop/main/claude-templates/install.sh | bash
#
# Environment variables:
#   CLAUDE_TEMPLATES_HOME  Install location (default: ~/.claude-templates)
#   CLAUDE_TEMPLATES_REF   Git ref to install (default: main)

set -euo pipefail

REPO="mentatzoe/Drops-of-slop"
REF="${CLAUDE_TEMPLATES_REF:-main}"
INSTALL_DIR="${CLAUDE_TEMPLATES_HOME:-$HOME/.claude-templates}"
TARBALL_URL="https://github.com/$REPO/archive/refs/heads/$REF.tar.gz"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()  { printf "${GREEN}>>>${NC} %s\n" "$1"; }
warn()  { printf "${YELLOW}WARN:${NC} %s\n" "$1" >&2; }
error() { printf "${RED}ERROR:${NC} %s\n" "$1" >&2; exit 1; }

# --- Preflight checks ---

command -v curl >/dev/null 2>&1 || error "curl is required but not installed."
command -v tar  >/dev/null 2>&1 || error "tar is required but not installed."

# --- Download and extract ---

info "Installing claude-templates ($REF) into $INSTALL_DIR ..."

TMPDIR_PATH="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_PATH"' EXIT

info "Downloading $TARBALL_URL ..."
curl -fsSL "$TARBALL_URL" -o "$TMPDIR_PATH/archive.tar.gz" \
  || error "Download failed. Check your network connection and that ref '$REF' exists."

info "Extracting claude-templates/ ..."
tar -xzf "$TMPDIR_PATH/archive.tar.gz" -C "$TMPDIR_PATH" \
  || error "Extraction failed. The downloaded archive may be corrupt."

# The tarball extracts to a directory named <repo>-<ref>/
EXTRACTED="$(ls -d "$TMPDIR_PATH"/Drops-of-slop-*/claude-templates 2>/dev/null)" \
  || error "Could not find claude-templates/ in the archive. Is the ref '$REF' correct?"

# --- Detect existing installation (update mode) ---

UPDATE_MODE=false
OLD_VERSION="unknown"
NEW_VERSION=$(cat "$EXTRACTED/VERSION" 2>/dev/null || echo "unknown")

if [ -d "$INSTALL_DIR" ]; then
    # Parse old version from .installed-version or VERSION file
    if [ -f "$INSTALL_DIR/.installed-version" ]; then
        OLD_VERSION=$(grep '^version=' "$INSTALL_DIR/.installed-version" 2>/dev/null | cut -d= -f2 || echo "")
    fi
    if [ -z "$OLD_VERSION" ] || [ "$OLD_VERSION" = "unknown" ]; then
        OLD_VERSION=$(cat "$INSTALL_DIR/VERSION" 2>/dev/null || echo "1.0.0")
    fi

    # Check if already up to date
    if [ "$OLD_VERSION" = "$NEW_VERSION" ] && [ "$REF" = "$(grep '^ref=' "$INSTALL_DIR/.installed-version" 2>/dev/null | cut -d= -f2 || echo "")" ]; then
        info "Already up to date (version $NEW_VERSION, ref $REF)."
        exit 0
    fi

    UPDATE_MODE=true
    echo ""
    printf "  ${BOLD}Updating from %s to %s${NC}\n" "$OLD_VERSION" "$NEW_VERSION"
    echo ""
fi

# --- Show changelog (update mode only) ---

if $UPDATE_MODE; then
    CHANGELOG="$EXTRACTED/CHANGELOG.md"
    if [ -f "$CHANGELOG" ]; then
        # Extract entries between old and new version
        CHANGES=$(python3 -c "
import sys

old_ver = '$OLD_VERSION'
new_ver = '$NEW_VERSION'
capture = False
lines = []

with open('$CHANGELOG') as f:
    for line in f:
        if line.startswith('## ['):
            ver = line.split('[')[1].split(']')[0]
            if ver == old_ver:
                break
            capture = True
        if capture:
            lines.append(line.rstrip())

if lines:
    print('\n'.join(lines))
" 2>/dev/null || true)

        if [ -n "$CHANGES" ]; then
            echo -e "  ${CYAN}What's new:${NC}"
            echo "$CHANGES" | sed 's/^/    /'
            echo ""
        fi
    fi
fi

# --- Install (atomic swap for updates, simple move for fresh) ---

if $UPDATE_MODE; then
    # Preserve .known-projects registry
    if [ -f "$INSTALL_DIR/.known-projects" ]; then
        cp "$INSTALL_DIR/.known-projects" "$EXTRACTED/.known-projects"
    fi

    # Atomic swap: old -> backup, new -> install dir, remove backup
    mv "$INSTALL_DIR" "$INSTALL_DIR.bak"
    mv "$EXTRACTED" "$INSTALL_DIR"
    rm -rf "$INSTALL_DIR.bak"
else
    mkdir -p "$(dirname "$INSTALL_DIR")"
    mv "$EXTRACTED" "$INSTALL_DIR"
fi

# --- Make scripts executable ---

find "$INSTALL_DIR" -name '*.sh' -exec chmod +x {} +
find "$INSTALL_DIR" -name '*.py' -exec chmod +x {} +

# --- Write version marker ---

cat > "$INSTALL_DIR/.installed-version" <<EOF
version=$NEW_VERSION
ref=$REF
installed=$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -u '+%Y-%m-%dT%H:%M:%SZ')
repo=$REPO
EOF

# --- Done ---

echo ""
echo "============================================"

if $UPDATE_MODE; then
    info "claude-templates updated successfully!"
    echo ""
    echo "  Location: $INSTALL_DIR"
    echo "  Version:  $OLD_VERSION -> $NEW_VERSION"
    echo "  Ref:      $REF"
    echo ""
    echo "  To refresh activated projects:"
    echo "    $INSTALL_DIR/refresh.sh ~/your-project"
    echo "    $INSTALL_DIR/refresh.sh --all"
else
    info "claude-templates installed successfully!"
    echo ""
    echo "  Location: $INSTALL_DIR"
    echo "  Version:  $NEW_VERSION"
    echo "  Ref:      $REF"
    echo ""
    echo "  Activate overlays on a project:"
    echo "    $INSTALL_DIR/activate.sh ~/my-project web-dev quality-assurance"
    echo ""
    echo "  Use a pre-built composition:"
    echo "    $INSTALL_DIR/activate.sh ~/my-project --composition fullstack-web"
    echo ""
    echo "  Migrate an existing project:"
    echo "    $INSTALL_DIR/migrate.sh ~/my-project"
fi

echo ""
echo "  Optional shell alias (add to ~/.bashrc or ~/.zshrc):"
echo "    alias claude-templates='$INSTALL_DIR/activate.sh'"
echo ""
echo "  To update, re-run:"
echo "    curl -fsSL https://raw.githubusercontent.com/$REPO/main/claude-templates/install.sh | bash"
echo ""
echo "  To uninstall:"
echo "    rm -rf $INSTALL_DIR"
echo "============================================"
