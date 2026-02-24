#!/usr/bin/env bats
# Tests for conflict detection, dependency resolution, and circular dependency detection.

load test_helper

setup() {
  setup_test_project

  # Create minimal overlay structure for testing conflicts and deps
  TEST_OVERLAYS="$(mktemp -d)"

  # Overlay A: conflicts with B
  mkdir -p "$TEST_OVERLAYS/overlay-a/rules"
  echo "# Overlay A" > "$TEST_OVERLAYS/overlay-a/rules/readme.md"
  cat > "$TEST_OVERLAYS/overlay-a/overlay.json" << 'EOF'
{"name": "overlay-a", "description": "test", "conflicts": ["overlay-b"], "depends": []}
EOF

  # Overlay B: conflicts with A
  mkdir -p "$TEST_OVERLAYS/overlay-b/rules"
  echo "# Overlay B" > "$TEST_OVERLAYS/overlay-b/rules/readme.md"
  cat > "$TEST_OVERLAYS/overlay-b/overlay.json" << 'EOF'
{"name": "overlay-b", "description": "test", "conflicts": ["overlay-a"], "depends": []}
EOF

  # Overlay C: depends on D
  mkdir -p "$TEST_OVERLAYS/overlay-c/rules"
  echo "# Overlay C" > "$TEST_OVERLAYS/overlay-c/rules/readme.md"
  cat > "$TEST_OVERLAYS/overlay-c/overlay.json" << 'EOF'
{"name": "overlay-c", "description": "test", "conflicts": [], "depends": ["overlay-d"]}
EOF

  # Overlay D: no deps
  mkdir -p "$TEST_OVERLAYS/overlay-d/rules"
  echo "# Overlay D" > "$TEST_OVERLAYS/overlay-d/rules/readme.md"
  cat > "$TEST_OVERLAYS/overlay-d/overlay.json" << 'EOF'
{"name": "overlay-d", "description": "test", "conflicts": [], "depends": []}
EOF

  # Overlay X: depends on Y (circular)
  mkdir -p "$TEST_OVERLAYS/overlay-x/rules"
  echo "# Overlay X" > "$TEST_OVERLAYS/overlay-x/rules/readme.md"
  cat > "$TEST_OVERLAYS/overlay-x/overlay.json" << 'EOF'
{"name": "overlay-x", "description": "test", "conflicts": [], "depends": ["overlay-y"]}
EOF

  # Overlay Y: depends on X (circular)
  mkdir -p "$TEST_OVERLAYS/overlay-y/rules"
  echo "# Overlay Y" > "$TEST_OVERLAYS/overlay-y/rules/readme.md"
  cat > "$TEST_OVERLAYS/overlay-y/overlay.json" << 'EOF'
{"name": "overlay-y", "description": "test", "conflicts": [], "depends": ["overlay-x"]}
EOF
}

teardown() {
  teardown_test_project
  [ -n "${TEST_OVERLAYS:-}" ] && rm -rf "$TEST_OVERLAYS"
}

# Helper: run activate.sh with custom overlay dir by creating a temporary
# template structure that points to our test overlays
_run_activate_with_test_overlays() {
  local overlays=("$@")

  # Create a temporary template dir that mimics the real structure
  local tmp_template
  tmp_template="$(mktemp -d)"

  # Copy base and scripts from real template
  cp -r "$TEMPLATE_DIR/base" "$tmp_template/base"
  cp -r "$TEMPLATE_DIR/scripts" "$tmp_template/scripts"
  [ -d "$TEMPLATE_DIR/personas" ] && cp -r "$TEMPLATE_DIR/personas" "$tmp_template/personas"
  [ -d "$TEMPLATE_DIR/agents" ] && cp -r "$TEMPLATE_DIR/agents" "$tmp_template/agents"
  [ -d "$TEMPLATE_DIR/compositions" ] && cp -r "$TEMPLATE_DIR/compositions" "$tmp_template/compositions"
  [ -f "$TEMPLATE_DIR/manifest.json" ] && cp "$TEMPLATE_DIR/manifest.json" "$tmp_template/manifest.json"
  echo "test" > "$tmp_template/VERSION"

  # Use our test overlays
  ln -sf "$TEST_OVERLAYS" "$tmp_template/overlays"

  # Copy activate.sh
  cp "$TEMPLATE_DIR/activate.sh" "$tmp_template/activate.sh"
  chmod +x "$tmp_template/activate.sh"

  run "$tmp_template/activate.sh" "$TEST_PROJECT" "${overlays[@]}"

  # Clean up temp template
  rm -rf "$tmp_template"
}

@test "conflict detection: blocks conflicting overlays" {
  _run_activate_with_test_overlays overlay-a overlay-b
  assert_failure
  assert_output --partial "Conflict"
}

@test "conflict detection: allows non-conflicting overlays" {
  _run_activate_with_test_overlays overlay-a overlay-d
  assert_success
}

@test "dependency resolution: auto-adds missing dependency" {
  _run_activate_with_test_overlays overlay-c
  assert_success
  assert_output --partial "Auto-adding dependency: overlay-d"

  # overlay-d should be in the state
  run python3 -c "
import json
state = json.load(open('$TEST_PROJECT/.claude/.activated-overlays.json'))
assert 'overlay-d' in state['overlays'], f'overlay-d not in {state[\"overlays\"]}'
print('OK')
"
  assert_success
  assert_output "OK"
}

@test "dependency resolution: does not duplicate existing dependency" {
  _run_activate_with_test_overlays overlay-c overlay-d
  assert_success

  # overlay-d should appear exactly once
  run python3 -c "
import json
state = json.load(open('$TEST_PROJECT/.claude/.activated-overlays.json'))
count = state['overlays'].count('overlay-d')
assert count == 1, f'overlay-d appears {count} times'
print('OK')
"
  assert_success
  assert_output "OK"
}

@test "circular dependency detection: detects and errors" {
  _run_activate_with_test_overlays overlay-x
  assert_failure
  assert_output --partial "Circular dependency"
}
