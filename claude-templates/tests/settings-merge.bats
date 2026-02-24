#!/usr/bin/env bats
# Tests for settings merge correctness via merge-configs.py.

load test_helper

setup() {
  setup_test_project
}

teardown() {
  teardown_test_project
}

@test "merge-configs: merges two settings files with deep merge" {
  cat > "$TEST_PROJECT/a.json" << 'EOF'
{
  "permissions": {
    "deny": ["WebFetch"],
    "allow": ["Read"]
  }
}
EOF

  cat > "$TEST_PROJECT/b.json" << 'EOF'
{
  "permissions": {
    "allow": ["Grep", "Glob"],
    "ask": ["Bash(docker:*)"]
  }
}
EOF

  run python3 "$TEMPLATE_DIR/scripts/merge-configs.py" \
    --type settings \
    --output "$TEST_PROJECT/merged.json" \
    "$TEST_PROJECT/a.json" "$TEST_PROJECT/b.json"
  assert_success

  run python3 -c "
import json
m = json.load(open('$TEST_PROJECT/merged.json'))
p = m['permissions']
# deny from a preserved
assert 'WebFetch' in p['deny'], f'deny missing WebFetch: {p[\"deny\"]}'
# allow from both merged, deduplicated
assert 'Read' in p['allow']
assert 'Grep' in p['allow']
assert 'Glob' in p['allow']
# ask from b added
assert 'Bash(docker:*)' in p['ask']
print('OK')
"
  assert_success
  assert_output "OK"
}

@test "merge-configs: list deduplication works" {
  cat > "$TEST_PROJECT/a.json" << 'EOF'
{"items": ["x", "y"]}
EOF

  cat > "$TEST_PROJECT/b.json" << 'EOF'
{"items": ["y", "z"]}
EOF

  run python3 "$TEMPLATE_DIR/scripts/merge-configs.py" \
    --type settings \
    --output "$TEST_PROJECT/merged.json" \
    "$TEST_PROJECT/a.json" "$TEST_PROJECT/b.json"
  assert_success

  run python3 -c "
import json
m = json.load(open('$TEST_PROJECT/merged.json'))
assert m['items'] == ['x', 'y', 'z'], f'Expected [x,y,z] got {m[\"items\"]}'
print('OK')
"
  assert_success
  assert_output "OK"
}

@test "merge-configs: MCP merge warns on duplicate server" {
  cat > "$TEST_PROJECT/a.json" << 'EOF'
{"mcpServers": {"myserver": {"command": "a"}}}
EOF

  cat > "$TEST_PROJECT/b.json" << 'EOF'
{"mcpServers": {"myserver": {"command": "b"}}}
EOF

  run python3 "$TEMPLATE_DIR/scripts/merge-configs.py" \
    --type mcp \
    --output "$TEST_PROJECT/merged.json" \
    "$TEST_PROJECT/a.json" "$TEST_PROJECT/b.json"
  assert_success

  # stderr should contain warning
  assert_output --partial "Warning: MCP server 'myserver'"

  # Last definition wins
  run python3 -c "
import json
m = json.load(open('$TEST_PROJECT/merged.json'))
assert m['mcpServers']['myserver']['command'] == 'b'
print('OK')
"
  assert_success
  assert_output "OK"
}

@test "merge-configs: MCP merge combines env var comments" {
  cat > "$TEST_PROJECT/a.json" << 'EOF'
{"_comment": "Required env vars: FOO_KEY", "mcpServers": {"a": {"command": "a"}}}
EOF

  cat > "$TEST_PROJECT/b.json" << 'EOF'
{"_comment": "Required env vars: BAR_KEY", "mcpServers": {"b": {"command": "b"}}}
EOF

  run python3 "$TEMPLATE_DIR/scripts/merge-configs.py" \
    --type mcp \
    --output "$TEST_PROJECT/merged.json" \
    "$TEST_PROJECT/a.json" "$TEST_PROJECT/b.json"
  assert_success

  run python3 -c "
import json
m = json.load(open('$TEST_PROJECT/merged.json'))
comment = m.get('_comment', '')
assert 'BAR_KEY' in comment, f'BAR_KEY not in comment: {comment}'
assert 'FOO_KEY' in comment, f'FOO_KEY not in comment: {comment}'
print('OK')
"
  assert_success
  assert_output "OK"
}

@test "merge-configs: overlay scalar values win over base" {
  cat > "$TEST_PROJECT/base.json" << 'EOF'
{"version": 1, "name": "base"}
EOF

  cat > "$TEST_PROJECT/overlay.json" << 'EOF'
{"version": 2}
EOF

  run python3 "$TEMPLATE_DIR/scripts/merge-configs.py" \
    --type settings \
    --output "$TEST_PROJECT/merged.json" \
    "$TEST_PROJECT/base.json" "$TEST_PROJECT/overlay.json"
  assert_success

  run python3 -c "
import json
m = json.load(open('$TEST_PROJECT/merged.json'))
assert m['version'] == 2, f'Expected 2, got {m[\"version\"]}'
assert m['name'] == 'base', f'Expected base, got {m[\"name\"]}'
print('OK')
"
  assert_success
  assert_output "OK"
}

@test "merge-configs: skips underscore-prefixed comment fields in settings" {
  cat > "$TEST_PROJECT/a.json" << 'EOF'
{"_comment": "should be ignored", "real": true}
EOF

  run python3 "$TEMPLATE_DIR/scripts/merge-configs.py" \
    --type settings \
    --output "$TEST_PROJECT/merged.json" \
    "$TEST_PROJECT/a.json"
  assert_success

  run python3 -c "
import json
m = json.load(open('$TEST_PROJECT/merged.json'))
assert '_comment' not in m, f'_comment should be skipped: {m}'
assert m['real'] == True
print('OK')
"
  assert_success
  assert_output "OK"
}
