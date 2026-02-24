#!/usr/bin/env bats
# Tests for activate.sh and deactivate.sh round-trip behavior.

load test_helper

setup() {
  setup_test_project
}

teardown() {
  teardown_test_project
}

@test "activate creates .claude directory structure" {
  run "$TEMPLATE_DIR/activate.sh" "$TEST_PROJECT" web-dev
  assert_success

  assert_dir_exists "$TEST_PROJECT/.claude/rules"
  assert_dir_exists "$TEST_PROJECT/.claude/skills"
  assert_dir_exists "$TEST_PROJECT/.claude/commands"
  assert_dir_exists "$TEST_PROJECT/.claude/agents"
  assert_dir_exists "$TEST_PROJECT/.claude/hooks"
}

@test "activate creates state file with correct schema" {
  run "$TEMPLATE_DIR/activate.sh" "$TEST_PROJECT" web-dev
  assert_success

  assert_file_exists "$TEST_PROJECT/.claude/.activated-overlays.json"

  # Verify schema version
  run python3 -c "
import json
state = json.load(open('$TEST_PROJECT/.claude/.activated-overlays.json'))
assert state['schema_version'] == 2, f'Expected schema v2, got {state[\"schema_version\"]}'
assert 'web-dev' in state['overlays'], 'web-dev not in overlays'
assert 'activated_at' in state
assert 'template_dir' in state
print('OK')
"
  assert_success
  assert_output "OK"
}

@test "activate symlinks base rules with base-- prefix" {
  run "$TEMPLATE_DIR/activate.sh" "$TEST_PROJECT" web-dev
  assert_success

  # Non-memory base rules should be symlinks
  for rule in "$TEST_PROJECT/.claude/rules"/base--*.md; do
    [ -f "$rule" ] || continue
    basename="$(basename "$rule")"
    case "$basename" in
      base--memory-*) assert_file_exists "$rule" ;;  # copies, not symlinks
      *) assert_link_exists "$rule" ;;                # symlinks
    esac
  done
}

@test "activate copies memory files (not symlinks)" {
  run "$TEMPLATE_DIR/activate.sh" "$TEST_PROJECT" web-dev
  assert_success

  for mem in memory-profile.md memory-preferences.md memory-decisions.md memory-sessions.md; do
    dest="$TEST_PROJECT/.claude/rules/base--$mem"
    assert_file_exists "$dest"
    # Must NOT be a symlink
    [ ! -L "$dest" ]
  done
}

@test "activate preserves existing memory files" {
  mkdir -p "$TEST_PROJECT/.claude/rules"
  echo "# Custom content" > "$TEST_PROJECT/.claude/rules/base--memory-profile.md"

  run "$TEMPLATE_DIR/activate.sh" "$TEST_PROJECT" web-dev
  assert_success

  # Original content should be preserved
  run cat "$TEST_PROJECT/.claude/rules/base--memory-profile.md"
  assert_output "# Custom content"
}

@test "activate generates CLAUDE.md" {
  run "$TEMPLATE_DIR/activate.sh" "$TEST_PROJECT" web-dev
  assert_success
  assert_file_exists "$TEST_PROJECT/CLAUDE.md"
}

@test "activate symlinks overlay rules with overlay prefix" {
  run "$TEMPLATE_DIR/activate.sh" "$TEST_PROJECT" web-dev
  assert_success

  # Should have at least one web-dev prefixed rule
  local found=0
  for rule in "$TEST_PROJECT/.claude/rules"/web-dev--*.md; do
    [ -f "$rule" ] && found=1 && break
  done
  [ "$found" -eq 1 ]
}

@test "activate generates merged settings.json" {
  run "$TEMPLATE_DIR/activate.sh" "$TEST_PROJECT" web-dev
  assert_success
  assert_file_exists "$TEST_PROJECT/.claude/settings.json"

  # Should be valid JSON
  run python3 -c "import json; json.load(open('$TEST_PROJECT/.claude/settings.json'))"
  assert_success
}

@test "activate copies hooks and makes them executable" {
  run "$TEMPLATE_DIR/activate.sh" "$TEST_PROJECT" web-dev
  assert_success

  for hook in "$TEST_PROJECT/.claude/hooks"/*; do
    [ -f "$hook" ] || continue
    assert_file_executable "$hook"
  done
}

@test "deactivate removes all symlinks" {
  "$TEMPLATE_DIR/activate.sh" "$TEST_PROJECT" web-dev

  run "$TEMPLATE_DIR/deactivate.sh" "$TEST_PROJECT"
  assert_success

  # No symlinks should remain in .claude/rules
  local symlinks
  symlinks=$(find "$TEST_PROJECT/.claude/rules" -type l 2>/dev/null | wc -l)
  [ "$symlinks" -eq 0 ]
}

@test "deactivate removes state file" {
  "$TEMPLATE_DIR/activate.sh" "$TEST_PROJECT" web-dev

  run "$TEMPLATE_DIR/deactivate.sh" "$TEST_PROJECT"
  assert_success
  assert_file_not_exists "$TEST_PROJECT/.claude/.activated-overlays.json"
}

@test "activate then deactivate is clean round-trip" {
  "$TEMPLATE_DIR/activate.sh" "$TEST_PROJECT" web-dev
  "$TEMPLATE_DIR/deactivate.sh" "$TEST_PROJECT"

  # .claude/ should be empty or removed
  if [ -d "$TEST_PROJECT/.claude" ]; then
    local remaining
    remaining=$(find "$TEST_PROJECT/.claude" -type f -o -type l 2>/dev/null | wc -l)
    [ "$remaining" -eq 0 ]
  fi
}

@test "activate with multiple overlays includes all" {
  run "$TEMPLATE_DIR/activate.sh" "$TEST_PROJECT" web-dev quality-assurance
  assert_success

  run python3 -c "
import json
state = json.load(open('$TEST_PROJECT/.claude/.activated-overlays.json'))
overlays = state['overlays']
assert 'web-dev' in overlays
assert 'quality-assurance' in overlays
print('OK')
"
  assert_success
  assert_output "OK"
}

@test "activate merges settings.local.json with highest precedence" {
  mkdir -p "$TEST_PROJECT/.claude"
  cat > "$TEST_PROJECT/.claude/settings.local.json" << 'EOF'
{
  "permissions": {
    "allow": [
      "WebFetch(domain:github.com)"
    ]
  }
}
EOF

  run "$TEMPLATE_DIR/activate.sh" "$TEST_PROJECT" web-dev
  assert_success

  # The local allow should be present in merged settings
  run python3 -c "
import json
settings = json.load(open('$TEST_PROJECT/.claude/settings.json'))
allows = settings.get('permissions', {}).get('allow', [])
assert 'WebFetch(domain:github.com)' in allows, f'Local allow not found in: {allows}'
print('OK')
"
  assert_success
  assert_output "OK"
}
