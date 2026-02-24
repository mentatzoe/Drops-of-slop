#!/usr/bin/env bash
# Shared test helper for claude-templates bats tests.
# Sources bats-support, bats-assert, and bats-file, and provides
# common setup/teardown for activation tests.

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$(cd "$TESTS_DIR/.." && pwd)"
HELPERS_DIR="$TESTS_DIR/helpers"

load "$HELPERS_DIR/bats-support/load.bash"
load "$HELPERS_DIR/bats-assert/load.bash"
load "$HELPERS_DIR/bats-file/load.bash"

# Create a temporary project directory for each test
setup_test_project() {
  TEST_PROJECT="$(mktemp -d)"
  mkdir -p "$TEST_PROJECT/.claude"
}

# Clean up temporary project directory
teardown_test_project() {
  if [ -n "${TEST_PROJECT:-}" ] && [ -d "$TEST_PROJECT" ]; then
    rm -rf "$TEST_PROJECT"
  fi
}
