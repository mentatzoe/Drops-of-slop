#!/usr/bin/env bats

setup() {
  export TEST_WORKSPACE="$(mktemp -d)"
  export PATH="$BATS_TEST_DIRNAME/mocks:$PATH"
  export BATS_RUN_TMPDIR="$TEST_WORKSPACE"
  
  cp "$BATS_TEST_DIRNAME/../update-gemini.sh" "$TEST_WORKSPACE/"
  cd "$TEST_WORKSPACE"
}

teardown() {
  rm -rf "$TEST_WORKSPACE"
}

@test "update-gemini.sh respects --dry-run and does not modify files" {
  mkdir -p .gemini
  echo '{"mcpServers": {"custom": {}}}' > .gemini/settings.json
  
  run bash ./update-gemini.sh --dry-run
  
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY-RUN MODE ACTIVATED"* ]]
  [[ "$output" == *"Would deep merge"* ]]
  
  # Ensure file was not modified
  run grep "custom" .gemini/settings.json
  [ "$status" -eq 0 ]
}

@test "update-gemini.sh accepts version flags safely" {
  run bash ./update-gemini.sh -v=v1.2.0 -d
  
  [ "$status" -eq 0 ]
  [[ "$output" == *"Updating Gemini CLI Workspace to version: v1.2.0..."* ]]
}
