#!/usr/bin/env bats
# Tests for refresh.sh behavior.

load test_helper

setup() {
  setup_test_project
}

teardown() {
  teardown_test_project
}

@test "refresh: re-establishes symlinks after activation" {
  "$TEMPLATE_DIR/activate.sh" "$TEST_PROJECT" web-dev

  # Count symlinks before refresh
  local before
  before=$(find "$TEST_PROJECT/.claude/rules" -type l 2>/dev/null | wc -l)

  run "$TEMPLATE_DIR/refresh.sh" "$TEST_PROJECT"
  assert_success

  # Count should be same or more after refresh
  local after
  after=$(find "$TEST_PROJECT/.claude/rules" -type l 2>/dev/null | wc -l)
  [ "$after" -ge "$before" ]
}

@test "refresh: preserves memory files" {
  "$TEMPLATE_DIR/activate.sh" "$TEST_PROJECT" web-dev

  # Write custom content to a memory file
  echo "# My custom decisions" > "$TEST_PROJECT/.claude/rules/base--memory-decisions.md"

  run "$TEMPLATE_DIR/refresh.sh" "$TEST_PROJECT"
  assert_success

  # Memory file should still have custom content
  run cat "$TEST_PROJECT/.claude/rules/base--memory-decisions.md"
  assert_output "# My custom decisions"
}

@test "refresh: dry-run makes no changes" {
  "$TEMPLATE_DIR/activate.sh" "$TEST_PROJECT" web-dev

  # Record state before
  local state_before
  state_before=$(cat "$TEST_PROJECT/.claude/.activated-overlays.json")

  run "$TEMPLATE_DIR/refresh.sh" --dry-run "$TEST_PROJECT"
  assert_success
  assert_output --partial "dry-run"

  # State file should be unchanged
  local state_after
  state_after=$(cat "$TEST_PROJECT/.claude/.activated-overlays.json")
  [ "$state_before" = "$state_after" ]
}

@test "refresh: merges settings.local.json if present" {
  "$TEMPLATE_DIR/activate.sh" "$TEST_PROJECT" web-dev

  # Add a settings.local.json
  cat > "$TEST_PROJECT/.claude/settings.local.json" << 'EOF'
{
  "permissions": {
    "allow": [
      "WebFetch(domain:example.com)"
    ]
  }
}
EOF

  run "$TEMPLATE_DIR/refresh.sh" "$TEST_PROJECT"
  assert_success

  run python3 -c "
import json
s = json.load(open('$TEST_PROJECT/.claude/settings.json'))
allows = s.get('permissions', {}).get('allow', [])
assert 'WebFetch(domain:example.com)' in allows, f'Local allow not found: {allows}'
print('OK')
"
  assert_success
  assert_output "OK"
}

@test "refresh: errors on project without activation state" {
  run "$TEMPLATE_DIR/refresh.sh" "$TEST_PROJECT"
  assert_failure
  assert_output --partial "No activation state"
}
