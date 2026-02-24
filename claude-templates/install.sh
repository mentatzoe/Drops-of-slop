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

# --- Install ---

if [ -d "$INSTALL_DIR" ]; then
  warn "Existing installation found at $INSTALL_DIR — replacing."
  rm -rf "$INSTALL_DIR"
fi

mkdir -p "$(dirname "$INSTALL_DIR")"
mv "$EXTRACTED" "$INSTALL_DIR"

# --- Make scripts executable ---

find "$INSTALL_DIR" -name '*.sh' -exec chmod +x {} +

# --- Write version marker ---

cat > "$INSTALL_DIR/.installed-version" <<EOF
ref=$REF
installed=$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -u '+%Y-%m-%dT%H:%M:%SZ')
repo=$REPO
EOF

# --- Done ---

echo ""
echo "============================================"
info "claude-templates installed successfully!"
echo ""
echo "  Location: $INSTALL_DIR"
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
