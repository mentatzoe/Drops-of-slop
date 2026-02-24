#!/usr/bin/env bats
# Tests for hook scripts — JSON protocol compliance and behavior.
# NOTE: Test data containing secret-like patterns is assembled at runtime
# to avoid triggering the pre-commit-safety hook on this test file itself.

load test_helper

setup() {
  setup_test_project
}

teardown() {
  teardown_test_project
}

# Helper: build secret test data at runtime to avoid tripping the hook on this file
_make_aws_key() { printf 'aws_key = "AKIA%s"' "IOSFODNN7EXAMPLE"; }
_make_ghp_token() { printf 'token = "ghp_%s"' "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghij"; }
_make_private_key_header() { printf '%s%s%s' '-----BEGIN ' 'RSA PRIVATE KEY' '-----'; }

# --- pre-commit-safety.sh ---

@test "pre-commit-safety: approves when no staged files" {
  cd "$TEST_PROJECT"
  git init -q

  run "$TEMPLATE_DIR/base/hooks/pre-commit-safety.sh"
  assert_success
  assert_output '{"decision": "approve"}'
}

@test "pre-commit-safety: blocks staged .env file" {
  cd "$TEST_PROJECT"
  git init -q
  echo "DB_HOST=localhost" > .env
  git add .env

  local json
  json=$("$TEMPLATE_DIR/base/hooks/pre-commit-safety.sh" 2>/dev/null)
  run python3 -c "
import json
data = json.loads('''${json}''')
assert data['decision'] == 'block', f'Expected block, got {data[\"decision\"]}'
assert '.env' in data['reason']
print('OK')
"
  assert_success
  assert_output "OK"
}

@test "pre-commit-safety: blocks AWS access key pattern" {
  cd "$TEST_PROJECT"
  git init -q
  _make_aws_key > config.txt
  git add config.txt

  local json
  json=$("$TEMPLATE_DIR/base/hooks/pre-commit-safety.sh" 2>/dev/null)
  run python3 -c "
import json
data = json.loads('''${json}''')
assert data['decision'] == 'block'
print('OK')
"
  assert_success
  assert_output "OK"
}

@test "pre-commit-safety: blocks private key pattern" {
  cd "$TEST_PROJECT"
  git init -q
  printf '%s\n%s\n' "$(_make_private_key_header)" 'MIIEowIBAAKCAQEA' > key.pem
  git add key.pem

  local json
  json=$("$TEMPLATE_DIR/base/hooks/pre-commit-safety.sh" 2>/dev/null)
  run python3 -c "
import json
data = json.loads('''${json}''')
assert data['decision'] == 'block'
print('OK')
"
  assert_success
  assert_output "OK"
}

@test "pre-commit-safety: blocks GitHub token pattern" {
  cd "$TEST_PROJECT"
  git init -q
  _make_ghp_token > config.txt
  git add config.txt

  local json
  json=$("$TEMPLATE_DIR/base/hooks/pre-commit-safety.sh" 2>/dev/null)
  run python3 -c "
import json
data = json.loads('''${json}''')
assert data['decision'] == 'block'
print('OK')
"
  assert_success
  assert_output "OK"
}

@test "pre-commit-safety: approves clean code" {
  cd "$TEST_PROJECT"
  git init -q
  echo 'console.log("hello world")' > app.js
  git add app.js

  run "$TEMPLATE_DIR/base/hooks/pre-commit-safety.sh"
  assert_success
  assert_output '{"decision": "approve"}'
}

@test "pre-commit-safety: allows .env.example" {
  cd "$TEST_PROJECT"
  git init -q
  echo "DB_HOST=your-host-here" > .env.example
  git add .env.example

  run "$TEMPLATE_DIR/base/hooks/pre-commit-safety.sh"
  assert_success
  assert_output '{"decision": "approve"}'
}

@test "pre-commit-safety: does not use grep -P for matching" {
  # Verify the hook uses grep -E, not grep -P (portability)
  # Exclude comment lines, then check for grep -P usage
  local count
  count=$(grep -v '^\s*#' "$TEMPLATE_DIR/base/hooks/pre-commit-safety.sh" | grep -c 'grep -P' || true)
  [ "$count" -eq 0 ]
}

# --- stop-learning-capture.sh ---

@test "stop-learning-capture: exits cleanly when stop_hook_active is true" {
  run bash -c 'echo "{\"stop_hook_active\": true, \"last_assistant_message\": \"I fixed the bug\"}" | "$1"' -- "$TEMPLATE_DIR/base/hooks/stop-learning-capture.sh"
  assert_success
  assert_output ""
}

@test "stop-learning-capture: blocks on strong pattern (fixed)" {
  local json
  json=$(echo '{"stop_hook_active": false, "last_assistant_message": "I fixed the issue with the config"}' | "$TEMPLATE_DIR/base/hooks/stop-learning-capture.sh")

  run python3 -c "
import json
data = json.loads('''${json}''')
assert data['decision'] == 'block'
print('OK')
"
  assert_success
  assert_output "OK"
}

@test "stop-learning-capture: blocks on strong pattern (discovered)" {
  local json
  json=$(echo '{"stop_hook_active": false, "last_assistant_message": "I discovered that the API was returning stale data"}' | "$TEMPLATE_DIR/base/hooks/stop-learning-capture.sh")

  run python3 -c "
import json
data = json.loads('''${json}''')
assert data['decision'] == 'block'
print('OK')
"
  assert_success
  assert_output "OK"
}

@test "stop-learning-capture: allows stop when no patterns match" {
  run bash -c 'echo "{\"stop_hook_active\": false, \"last_assistant_message\": \"Here is the summary you requested.\"}" | "$1"' -- "$TEMPLATE_DIR/base/hooks/stop-learning-capture.sh"
  assert_success
  assert_output ""
}

# --- JSON protocol compliance ---

@test "pre-commit-safety: all outputs are valid JSON" {
  cd "$TEST_PROJECT"
  git init -q

  # Test approve path
  local approve_json
  approve_json=$("$TEMPLATE_DIR/base/hooks/pre-commit-safety.sh" 2>/dev/null)
  run python3 -c "import json; json.loads('''${approve_json}'''); print('OK')"
  assert_success
  assert_output "OK"

  # Test block path
  echo "DB_HOST=localhost" > .env
  git add .env
  local block_json
  block_json=$("$TEMPLATE_DIR/base/hooks/pre-commit-safety.sh" 2>/dev/null)
  run python3 -c "import json; d=json.loads('''${block_json}'''); assert 'decision' in d; assert 'reason' in d or d['decision']=='approve'; print('OK')"
  assert_success
  assert_output "OK"
}
