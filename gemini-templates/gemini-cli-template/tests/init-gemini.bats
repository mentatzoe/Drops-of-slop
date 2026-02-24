#!/usr/bin/env bats

setup() {
  export TEST_WORKSPACE="$(mktemp -d)"
  export PATH="$BATS_TEST_DIRNAME/mocks:$PATH"
  export BATS_RUN_TMPDIR="$TEST_WORKSPACE"
  
  # Copy the script under test
  cp "$BATS_TEST_DIRNAME/../init-gemini.sh" "$TEST_WORKSPACE/"
  cd "$TEST_WORKSPACE"
}

teardown() {
  rm -rf "$TEST_WORKSPACE"
}

@test "init-gemini.sh requires migration if .gemini exists and aborts without confirmation" {
  mkdir -p .gemini
  
  # When running non-interactively without y, it should abort
  run bash ./init-gemini.sh < /dev/null
  
  [ "$status" -eq 1 ]
  [[ "$output" == *"Existing Gemini configuration detected."* ]]
  [[ "$output" == *"Aborting initialization"* ]]
}

@test "init-gemini.sh respects --dry-run" {
  mkdir -p .gemini
  
  run bash ./init-gemini.sh --dry-run
  
  [ "$status" -eq 0 ]
  [[ "$output" == *"[Dry-Run] Migration Report:"* ]]
  [[ "$output" == *"Would backup legacy files"* ]]
}

@test "init-gemini.sh runs cleanly when no existing config is present (dry run)" {
  run bash ./init-gemini.sh -d
  
  [ "$status" -eq 0 ]
  [[ "$output" == *"[Dry-Run] Clean Install Report:"* ]]
}
